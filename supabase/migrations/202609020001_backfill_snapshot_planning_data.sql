-- Bridge the last production snapshot-only planning facts into the canonical
-- relational model. This migration is intentionally idempotent and leaves the
-- compatibility snapshot untouched until client parity has been validated.

with latest_snapshots as (
  select distinct on (user_id)
    user_id,
    updated_at,
    payload
  from public.athlete_snapshots
  order by user_id, updated_at desc
), snapshot_goals as (
  select
    athlete.id as athlete_id,
    snapshot.updated_at as snapshot_updated_at,
    goal.value as goal,
    nullif(goal.value ->> 'name', '') as name,
    case
      when coalesce(goal.value ->> 'eventDate', '')
        ~ '^\d{4}-\d{2}-\d{2}'
      then left(goal.value ->> 'eventDate', 10)::date
    end as event_date
  from latest_snapshots snapshot
  join public.athletes athlete on athlete.user_id = snapshot.user_id
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(snapshot.payload -> 'eventGoals') = 'array'
      then snapshot.payload -> 'eventGoals'
      else '[]'::jsonb
    end
  ) goal(value)
)
insert into public.goals (
  athlete_id,
  name,
  event_date,
  event_type,
  priority,
  distance_metres,
  elevation_metres,
  target_performance,
  notes
)
select
  source.athlete_id,
  source.name,
  source.event_date,
  coalesce(nullif(lower(source.goal ->> 'terrain'), ''), 'cycling_event'),
  case upper(source.goal ->> 'priority')
    when 'A' then 'A'::public.goal_priority
    when 'B' then 'B'::public.goal_priority
    else 'C'::public.goal_priority
  end,
  case
    when coalesce(source.goal ->> 'distanceKm', '')
      ~ '^\d+(\.\d+)?$'
    then (source.goal ->> 'distanceKm')::numeric * 1000
  end,
  case
    when coalesce(source.goal ->> 'elevationMetres', '') ~ '^\d+(\.\d+)?$'
    then (source.goal ->> 'elevationMetres')::numeric
  end,
  nullif(source.goal ->> 'target', ''),
  concat(
    'Migrated from compatibility snapshot ',
    source.snapshot_updated_at::text,
    '; terrain=', coalesce(source.goal ->> 'terrain', 'unknown'),
    '; availableDays=', coalesce(source.goal ->> 'availableDays', 'unknown'),
    '; longRideMinutes=', coalesce(source.goal ->> 'longRideMinutes', 'unknown')
  )
from snapshot_goals source
where source.name is not null
  and source.event_date is not null
  and not exists (
    select 1
    from public.goals existing
    where existing.athlete_id = source.athlete_id
      and existing.name = source.name
      and existing.event_date = source.event_date
  );

with latest_snapshots as (
  select distinct on (user_id)
    user_id,
    updated_at,
    payload
  from public.athlete_snapshots
  order by user_id, updated_at desc
), snapshot_sessions as (
  select
    athlete.id as athlete_id,
    snapshot.updated_at as snapshot_updated_at,
    session.value as session,
    case
      when coalesce(session.value ->> 'day', '') ~ '^\d{4}-\d{2}-\d{2}'
      then left(session.value ->> 'day', 10)::date
    end as scheduled_date,
    lower(regexp_replace(
      coalesce(nullif(session.value ->> 'sessionType', ''), 'endurance'),
      '([a-z0-9])([A-Z])', '\1_\2', 'g'
    )) as session_type
  from latest_snapshots snapshot
  join public.athletes athlete on athlete.user_id = snapshot.user_id
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(snapshot.payload -> 'plannedSessions') = 'array'
      then snapshot.payload -> 'plannedSessions'
      else '[]'::jsonb
    end
  ) session(value)
), normalized_sessions as (
  select
    source.*,
    case
      when session_type = 'recovery' then 'RECOVERY_30'
      when session_type in ('endurance', 'long_endurance', 'zone_2') then 'ENDURANCE_45'
      when session_type = 'tempo' then 'TEMPO_60'
      when session_type in ('sweet_spot', 'sweetspot') then 'SWEET_SPOT_60'
      when session_type in ('threshold', 'over_under') then 'THRESHOLD_65'
      when session_type in ('vo2', 'vo2_max', 'vo2max') then 'VO2_MAX_55'
      when session_type = 'anaerobic' then 'ANAEROBIC_50'
      when session_type = 'sprint' then 'SPRINT_45'
      when session_type = 'neuromuscular' then 'NEUROMUSCULAR_45'
      when session_type = 'cadence' then 'CADENCE_45'
      when session_type in ('climbing', 'climbing_endurance') then 'CLIMBING_75'
      when session_type in ('race_simulation', 'race_sim') then 'RACE_SIM_120'
      else 'ENDURANCE_45'
    end as workout_id
  from snapshot_sessions source
)
insert into public.planned_sessions (
  athlete_id,
  scheduled_date,
  workout_library_id,
  session_type,
  primary_adaptation,
  purpose,
  planned_duration_minutes,
  planned_load,
  original_workout_id,
  current_workout_id,
  adaptation_status,
  completion_status,
  source_evidence,
  algorithm_version
)
select
  source.athlete_id,
  source.scheduled_date,
  workout.id,
  workout.session_type,
  workout.primary_adaptation,
  coalesce(nullif(source.session ->> 'title', ''), workout.primary_adaptation),
  greatest(
    1,
    case
      when coalesce(source.session ->> 'durationMinutes', '') ~ '^\d+$'
      then (source.session ->> 'durationMinutes')::integer
      else workout.duration_minutes
    end
  ),
  case
    when coalesce(source.session ->> 'targetLoad', '') ~ '^\d+(\.\d+)?$'
    then (source.session ->> 'targetLoad')::numeric
  end,
  workout.id,
  workout.id,
  case
    when coalesce(source.session ->> 'adaptationReason', '') <> ''
    then 'modified'
    else 'unchanged'
  end,
  'planned',
  jsonb_build_object(
    'source', 'compatibility_snapshot',
    'snapshot_updated_at', source.snapshot_updated_at,
    'legacy_session_type', source.session ->> 'sessionType',
    'legacy_title', source.session ->> 'title',
    'legacy_origin', source.session ->> 'origin',
    'legacy_confirmed', source.session -> 'confirmed',
    'legacy_prescription', source.session ->> 'prescription',
    'legacy_adaptation_reason', source.session ->> 'adaptationReason'
  ),
  'snapshot-bridge-v1'
from normalized_sessions source
join public.workout_library workout on workout.id = source.workout_id
where source.scheduled_date is not null
  and not exists (
    select 1
    from public.planned_sessions existing
    where existing.athlete_id = source.athlete_id
      and existing.scheduled_date = source.scheduled_date
  );
