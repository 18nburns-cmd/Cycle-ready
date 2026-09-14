create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault;

create table public.integration_scheduler_authorization (
  id boolean primary key default true check (id),
  secret_digest text not null,
  rotated_at timestamptz not null default now()
);

alter table public.integration_scheduler_authorization enable row level security;
revoke all on public.integration_scheduler_authorization from anon, authenticated;
grant all on public.integration_scheduler_authorization to service_role;

create or replace function public.notify_stale_integrations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer;
begin
  insert into public.notifications (
    athlete_id, notification_type, title, body, payload, scheduled_for
  )
  select
    i.athlete_id,
    'integration_sync_alert',
    'Training data sync needs attention',
    initcap(replace(i.provider, '_', '.')) ||
      ' has not synchronized successfully in the last six hours.',
    jsonb_build_object(
      'integration_id', i.id,
      'provider', i.provider,
      'last_sync_at', i.last_sync_at,
      'sync_error', i.sync_error
    ),
    now()
  from public.integrations i
  where i.connection_status = 'connected'
    and (i.last_sync_at is null or i.last_sync_at < now() - interval '6 hours')
    and not exists (
      select 1
      from public.notifications n
      where n.athlete_id = i.athlete_id
        and n.notification_type = 'integration_sync_alert'
        and n.payload ->> 'integration_id' = i.id::text
        and n.created_at > now() - interval '24 hours'
    );
  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

revoke all on function public.notify_stale_integrations() from public, anon, authenticated;
grant execute on function public.notify_stale_integrations() to service_role;

do $$
declare
  scheduler_secret text := encode(extensions.gen_random_bytes(32), 'hex');
  existing_job bigint;
begin
  insert into public.integration_scheduler_authorization (id, secret_digest)
  values (true, encode(extensions.digest(scheduler_secret, 'sha256'), 'hex'))
  on conflict (id) do update
    set secret_digest = excluded.secret_digest,
        rotated_at = now();
  perform vault.create_secret(
    scheduler_secret,
    'cycle_ready_scheduler_secret_v1',
    'Secret used only by the database scheduler to invoke intervals-sync'
  );

  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-intervals-hourly';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;

  perform cron.schedule(
    'cycle-ready-intervals-hourly',
    '17 * * * *',
    $job$select net.http_post(
        url := 'https://tvqzvuvthpvnzkvikdmy.supabase.co/functions/v1/intervals-sync',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cycle-ready-scheduler-secret',
          (select decrypted_secret from vault.decrypted_secrets
           where name = 'cycle_ready_scheduler_secret_v1')
        ),
        body := jsonb_build_object('trigger', 'scheduled'),
        timeout_milliseconds := 10000
      );$job$
  );

  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-integration-monitor';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'cycle-ready-integration-monitor',
    '42 * * * *',
    'select public.notify_stale_integrations();'
  );
end;
$$;
