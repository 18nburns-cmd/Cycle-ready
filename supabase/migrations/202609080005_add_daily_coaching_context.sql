alter table public.athletes
  add column if not exists coaching_timezone text not null default 'Europe/London'
  check (length(trim(coaching_timezone)) between 1 and 80);

create or replace function public.assemble_daily_coaching_context(
  requested_athlete_id uuid,
  requested_date date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  result jsonb;
begin
  if auth.role() <> 'service_role'
     and not public.owns_athlete(requested_athlete_id) then
    raise exception 'Athlete context access denied';
  end if;

  select jsonb_build_object(
    'contract_version', '1.0',
    'athlete_id', athlete.id,
    'coaching_date', requested_date,
    'timezone', athlete.coaching_timezone,
    'requested_at', now(),
    'planned_workout', case when planned.id is null then null else jsonb_build_object(
      'id', coalesce(planned.current_workout_id, planned.id::text),
      'family', planned.session_type,
      'title', planned.purpose,
      'intensity', case
        when planned.session_type = 'rest' then 'REST'
        when planned.session_type = 'recovery' then 'RECOVERY'
        when planned.session_type = 'endurance' then 'ENDURANCE'
        when planned.session_type in ('tempo', 'sweet_spot') then 'MODERATE'
        else 'HIGH'
      end,
      'duration_minutes', planned.planned_duration_minutes,
      'target_load', coalesce(planned.planned_load, 0)
    ) end,
    'evidence', jsonb_build_object(
      'readiness', coalesce(readiness.readiness_score, 50),
      'fatigue_risk', case upper(coalesce(readiness.fatigue_risk, 'MEDIUM'))
        when 'LOW' then 25 when 'HIGH' then 75 else 50 end,
      'training_progress', 50,
      'goal_alignment', case when goal.id is null then 50 else 75 end,
      'hrv_change_percent', case
        when wellness.hrv_ms is null or athlete.hrv_baseline_ms is null then null
        else round((wellness.hrv_ms - athlete.hrv_baseline_ms) * 100 /
          nullif(athlete.hrv_baseline_ms, 0), 2) end,
      'resting_hr_delta', case
        when wellness.resting_hr is null or athlete.resting_hr_baseline is null then null
        else wellness.resting_hr - athlete.resting_hr_baseline end,
      'sleep_deficit_minutes', case when wellness.sleep_minutes is null then null
        else greatest(0, 480 - wellness.sleep_minutes) end,
      'acute_chronic_load_ratio', load.acwr,
      'fatigue', coalesce(wellness.fatigue, 3),
      'soreness', coalesce(wellness.soreness, 3),
      'stress', coalesce(wellness.stress, 3),
      'illness_symptoms', coalesce(wellness.illness_flag, false),
      'injury_pain', coalesce(wellness.injury_or_pain_flag, false),
      'recent_hard_session', coalesce(load.recent_hard_session, false),
      'available_minutes', availability.maximum_duration_minutes,
      'evidence_updated_at', greatest(
        coalesce(readiness.calculated_at, '-infinity'::timestamptz),
        coalesce(wellness.resolved_at, '-infinity'::timestamptz),
        coalesce(load.last_activity_at, '-infinity'::timestamptz),
        athlete.updated_at
      )
    )
  ) into result
  from public.athletes athlete
  left join lateral (
    select r.* from public.daily_readiness r
    where r.athlete_id = athlete.id and r.readiness_date = requested_date
    order by r.calculated_at desc limit 1
  ) readiness on true
  left join public.daily_wellness_resolved wellness
    on wellness.athlete_id = athlete.id and wellness.recorded_date = requested_date
  left join lateral (
    select p.* from public.planned_sessions p
    where p.athlete_id = athlete.id and p.scheduled_date = requested_date
    order by p.updated_at desc limit 1
  ) planned on true
  left join lateral (
    select g.* from public.goals g
    where g.athlete_id = athlete.id and g.event_date >= requested_date
    order by g.priority, g.event_date limit 1
  ) goal on true
  left join public.athlete_availability availability
    on availability.athlete_id = athlete.id
    and availability.day_of_week = extract(isodow from requested_date)::smallint
  left join lateral (
    select
      max(a.started_at) as last_activity_at,
      bool_or(a.training_load >= 60 and a.started_at >= requested_date - interval '48 hours')
        as recent_hard_session,
      case when sum(a.training_load) filter (
        where a.started_at >= requested_date - interval '7 days') is null then null
      else round(
        (sum(a.training_load) filter (
          where a.started_at >= requested_date - interval '7 days')) /
        nullif((sum(a.training_load) filter (
          where a.started_at >= requested_date - interval '28 days')) / 4, 0),
        3
      ) end as acwr
    from public.activities a
    where a.athlete_id = athlete.id
      and a.started_at < requested_date + interval '1 day'
      and a.started_at >= requested_date - interval '28 days'
  ) load on true
  where athlete.id = requested_athlete_id;

  if result is null then raise exception 'Athlete not found'; end if;
  return result;
end;
$$;

grant execute on function public.assemble_daily_coaching_context(uuid, date)
  to authenticated, service_role;
