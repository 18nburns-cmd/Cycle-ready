create or replace function public.claim_workout_delivery_jobs(p_limit integer default 10)
returns setof public.workout_delivery_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service_role required';
  end if;

  update public.workout_delivery_outbox
  set status = 'failed',
      next_attempt_at = now(),
      last_error = 'Worker lease expired before acknowledgement.'
  where status = 'processing'
    and next_attempt_at < now() - interval '10 minutes';

  update public.workout_delivery_outbox o
  set status = 'completed',
      completed_at = now(),
      last_error = 'Superseded by a newer desired workout version.'
  from public.workout_deliveries d
  where o.delivery_id = d.id
    and o.status in ('pending', 'failed')
    and o.content_hash <> d.desired_content_hash;

  return query
  with selected as (
    select o.id
    from public.workout_delivery_outbox o
    join public.workout_deliveries d on d.id = o.delivery_id
    where o.status in ('pending', 'failed')
      and o.next_attempt_at <= now()
      and o.content_hash = d.desired_content_hash
    order by o.created_at, o.id
    for update of o skip locked
    limit greatest(1, least(coalesce(p_limit, 10), 25))
  )
  update public.workout_delivery_outbox o
  set status = 'processing',
      attempt_count = o.attempt_count + 1,
      next_attempt_at = now(),
      last_error = null
  from selected
  where o.id = selected.id
  returning o.*;
end;
$$;

revoke all on function public.claim_workout_delivery_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_workout_delivery_jobs(integer) to service_role;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-workout-delivery';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;

  perform cron.schedule(
    'cycle-ready-workout-delivery',
    '*/2 * * * *',
    $job$select net.http_post(
      url := 'https://tvqzvuvthpvnzkvikdmy.supabase.co/functions/v1/deliver-workouts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cycle-ready-scheduler-secret',
        (select decrypted_secret from vault.decrypted_secrets
         where name = 'cycle_ready_scheduler_secret_v1')
      ),
      body := jsonb_build_object('trigger', 'scheduled'),
      timeout_milliseconds := 30000
    );$job$
  );
end;
$$;
