create or replace function public.get_daily_coaching_status(requested_athlete_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare athlete_timezone text;
declare local_now timestamp;
declare next_local timestamp;
declare latest_run public.daily_coaching_runs%rowtype;
begin
  if auth.role() <> 'service_role'
     and not public.owns_athlete(requested_athlete_id) then
    raise exception 'Athlete status access denied';
  end if;
  select coaching_timezone into athlete_timezone from public.athletes
  where id = requested_athlete_id;
  if athlete_timezone is null then raise exception 'Athlete not found'; end if;

  local_now := now() at time zone athlete_timezone;
  next_local := date_trunc('day', local_now) + interval '5 hours';
  if local_now >= next_local then next_local := next_local + interval '1 day'; end if;
  select * into latest_run from public.daily_coaching_runs
  where athlete_id = requested_athlete_id
  order by started_at desc limit 1;

  return jsonb_build_object(
    'last_run_at', latest_run.started_at,
    'next_run_at', coalesce(latest_run.next_retry_at,
      next_local at time zone athlete_timezone),
    'model_version', latest_run.model_version,
    'status', coalesce(latest_run.status, 'NEVER_RUN'),
    'failure_code', latest_run.error_code,
    'failure_message', latest_run.error_message,
    'attempt_number', coalesce(latest_run.attempt_number, 0),
    'timezone', athlete_timezone
  );
end;
$$;

grant execute on function public.get_daily_coaching_status(uuid)
  to authenticated, service_role;
