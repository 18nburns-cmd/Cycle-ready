create or replace function public.validate_coaching_timezone()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1 from pg_timezone_names where name = new.coaching_timezone
  ) then
    raise exception 'Unknown coaching timezone: %', new.coaching_timezone;
  end if;
  return new;
end;
$$;

drop trigger if exists athletes_validate_coaching_timezone on public.athletes;
create trigger athletes_validate_coaching_timezone
  before insert or update of coaching_timezone on public.athletes
  for each row execute function public.validate_coaching_timezone();

create or replace function public.run_due_daily_coaching(run_at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  athlete record;
  local_time timestamp;
  queued_count integer := 0;
  scheduler_secret text;
begin
  select decrypted_secret into scheduler_secret
  from vault.decrypted_secrets
  where name = 'cycle_ready_scheduler_secret_v1'
  order by created_at desc limit 1;
  if scheduler_secret is null then
    raise exception 'CycleReady scheduler secret is unavailable';
  end if;

  for athlete in select id, coaching_timezone from public.athletes loop
    local_time := run_at at time zone athlete.coaching_timezone;
    if local_time::date = (run_at at time zone athlete.coaching_timezone)::date
       and (
         (extract(hour from local_time) = 5
          and extract(minute from local_time) < 15
          and not exists (
            select 1 from public.daily_coaching_recommendations recommendation
            where recommendation.athlete_id = athlete.id
              and recommendation.coaching_date = local_time::date
              and recommendation.status = 'COMPLETED'
          ))
         or exists (
           select 1
           from public.daily_coaching_recommendations recommendation
           where recommendation.athlete_id = athlete.id
             and recommendation.coaching_date = local_time::date
             and recommendation.status = 'COMPLETED'
             and greatest(
               coalesce((select max(r.calculated_at) from public.daily_readiness r
                 where r.athlete_id = athlete.id and r.readiness_date = local_time::date), '-infinity'::timestamptz),
               coalesce((select max(w.resolved_at) from public.daily_wellness_resolved w
                 where w.athlete_id = athlete.id and w.recorded_date = local_time::date), '-infinity'::timestamptz),
               coalesce((select max(a.updated_at) from public.activities a
                 where a.athlete_id = athlete.id and (a.started_at at time zone athlete.coaching_timezone)::date = local_time::date), '-infinity'::timestamptz),
               coalesce((select max(p.updated_at) from public.planned_sessions p
                 where p.athlete_id = athlete.id and p.scheduled_date = local_time::date), '-infinity'::timestamptz)
             ) > recommendation.generated_at
         )
       ) then
      perform net.http_post(
        url := 'https://tvqzvuvthpvnzkvikdmy.supabase.co/functions/v1/daily-coaching',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cycle-ready-scheduler-secret', scheduler_secret
        ),
        body := jsonb_build_object(
          'contract_version', '1.0',
          'athlete_id', athlete.id,
          'coaching_date', local_time::date,
          'timezone', athlete.coaching_timezone,
          'requested_at', run_at
        ),
        timeout_milliseconds := 30000
      );
      queued_count := queued_count + 1;
    end if;
  end loop;
  return queued_count;
end;
$$;

revoke all on function public.run_due_daily_coaching(timestamptz)
  from public, anon, authenticated;
grant execute on function public.run_due_daily_coaching(timestamptz)
  to service_role;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-daily-coaching';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'cycle-ready-daily-coaching',
    '*/15 * * * *',
    'select public.run_due_daily_coaching(now());'
  );
end;
$$;
