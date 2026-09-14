create table public.daily_coaching_runs (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  coaching_date date not null,
  timezone text not null,
  attempt_number integer not null check (attempt_number between 1 and 10),
  status text not null check (status in ('RUNNING', 'COMPLETED', 'FAILED', 'RETRYING')),
  model_version text not null,
  error_code text,
  error_message text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  next_retry_at timestamptz,
  unique (athlete_id, coaching_date, attempt_number)
);

create index daily_coaching_runs_retry_due
  on public.daily_coaching_runs (next_retry_at)
  where status = 'FAILED';

alter table public.daily_coaching_runs enable row level security;
create policy daily_coaching_runs_owner_read on public.daily_coaching_runs
  for select to authenticated using (public.owns_athlete(athlete_id));
grant select on public.daily_coaching_runs to authenticated;

create or replace function public.retry_failed_daily_coaching(run_at timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare failed_run record;
declare scheduler_secret text;
declare queued integer := 0;
begin
  select decrypted_secret into scheduler_secret from vault.decrypted_secrets
  where name = 'cycle_ready_scheduler_secret_v1'
  order by created_at desc limit 1;
  if scheduler_secret is null then return 0; end if;

  for failed_run in
    select distinct on (athlete_id, coaching_date) *
    from public.daily_coaching_runs
    where status = 'FAILED' and next_retry_at <= run_at and attempt_number < 10
    order by athlete_id, coaching_date, attempt_number desc
  loop
    update public.daily_coaching_runs set status = 'RETRYING'
    where id = failed_run.id and status = 'FAILED';
    if found then
      perform net.http_post(
        url := 'https://tvqzvuvthpvnzkvikdmy.supabase.co/functions/v1/daily-coaching',
        headers := jsonb_build_object('Content-Type', 'application/json',
          'x-cycle-ready-scheduler-secret', scheduler_secret),
        body := jsonb_build_object(
          'contract_version', '1.0', 'athlete_id', failed_run.athlete_id,
          'coaching_date', failed_run.coaching_date, 'timezone', failed_run.timezone,
          'requested_at', run_at
        ),
        timeout_milliseconds := 30000
      );
      queued := queued + 1;
    end if;
  end loop;
  return queued;
end;
$$;

revoke all on function public.retry_failed_daily_coaching(timestamptz)
  from public, anon, authenticated;
grant execute on function public.retry_failed_daily_coaching(timestamptz)
  to service_role;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-daily-coaching-retry';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule('cycle-ready-daily-coaching-retry', '7,22,37,52 * * * *',
    'select public.retry_failed_daily_coaching(now());');
end;
$$;
