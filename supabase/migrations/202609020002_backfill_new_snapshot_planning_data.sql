-- Re-run the non-destructive bridge after the athlete supplied real planning
-- inputs. Future clients write these canonical relations directly.

with source as (
  select a.id athlete_id, s.updated_at, g.value goal
  from public.athlete_snapshots s
  join public.athletes a on a.user_id = s.user_id
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(s.payload -> 'eventGoals') = 'array'
      then s.payload -> 'eventGoals' else '[]'::jsonb end
  ) g(value)
), valid as (
  select *, case
    when jsonb_typeof(goal -> 'eventDate') = 'number'
      then (to_timestamp((goal ->> 'eventDate')::numeric / 1000) at time zone 'Europe/London')::date
    else left(goal ->> 'eventDate', 10)::date
  end event_date
  from source
  where coalesce(goal ->> 'name', '') <> ''
    and (jsonb_typeof(goal -> 'eventDate') = 'number'
      or coalesce(goal ->> 'eventDate', '') ~ '^\d{4}-\d{2}-\d{2}')
)
insert into public.goals (
  athlete_id, name, event_date, event_type, priority, distance_metres,
  elevation_metres, target_performance, notes
)
select
  v.athlete_id,
  v.goal ->> 'name',
  v.event_date,
  coalesce(nullif(lower(v.goal ->> 'terrain'), ''), 'cycling_event'),
  case upper(v.goal ->> 'priority')
    when 'A' then 'A'::public.goal_priority
    when 'B' then 'B'::public.goal_priority
    else 'C'::public.goal_priority end,
  case when coalesce(v.goal ->> 'distanceKm', '') ~ '^\d+(\.\d+)?$'
    then (v.goal ->> 'distanceKm')::numeric * 1000 end,
  case when coalesce(v.goal ->> 'elevationMetres', '') ~ '^\d+(\.\d+)?$'
    then (v.goal ->> 'elevationMetres')::numeric end,
  nullif(v.goal ->> 'target', ''),
  concat('Migrated from compatibility snapshot ', v.updated_at::text,
    '; availableDays=', coalesce(v.goal ->> 'availableDays', 'unknown'),
    '; longRideMinutes=', coalesce(v.goal ->> 'longRideMinutes', 'unknown'))
from valid v
where not exists (
  select 1 from public.goals g where g.athlete_id = v.athlete_id
    and g.name = (v.goal ->> 'name') and g.event_date = v.event_date
);

with source as (
  select a.id athlete_id, s.updated_at, p.value session,
    case
      when jsonb_typeof(p.value -> 'day') = 'number'
        then (to_timestamp((p.value ->> 'day')::numeric / 1000) at time zone 'Europe/London')::date
      else left(p.value ->> 'day', 10)::date
    end scheduled_date,
    lower(regexp_replace(coalesce(nullif(p.value ->> 'sessionType', ''),
      'endurance'), '([a-z0-9])([A-Z])', '\1_\2', 'g')) session_type
  from public.athlete_snapshots s
  join public.athletes a on a.user_id = s.user_id
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(s.payload -> 'plannedSessions') = 'array'
      then s.payload -> 'plannedSessions' else '[]'::jsonb end
  ) p(value)
  where jsonb_typeof(p.value -> 'day') = 'number'
    or coalesce(p.value ->> 'day', '') ~ '^\d{4}-\d{2}-\d{2}'
), mapped as (
  select source.*,
    case
      when session_type = 'recovery' then 'RECOVERY_30'
      when session_type in ('tempo') then 'TEMPO_60'
      when session_type in ('sweet_spot','sweetspot') then 'SWEET_SPOT_60'
      when session_type in ('threshold','over_under','intervals') then 'THRESHOLD_65'
      when session_type in ('vo2','vo2_max','vo2max') then 'VO2_MAX_55'
      when session_type = 'anaerobic' then 'ANAEROBIC_50'
      when session_type = 'sprint' then 'SPRINT_45'
      when session_type = 'neuromuscular' then 'NEUROMUSCULAR_45'
      when session_type = 'cadence' then 'CADENCE_45'
      when session_type in ('climbing','climbing_endurance') then 'CLIMBING_75'
      when session_type in ('race_simulation','race_sim') then 'RACE_SIM_120'
      else 'ENDURANCE_45' end workout_id
  from source
)
insert into public.planned_sessions (
  athlete_id, scheduled_date, workout_library_id, session_type,
  primary_adaptation, purpose, planned_duration_minutes, planned_load,
  original_workout_id, current_workout_id, adaptation_status,
  completion_status, source_evidence, algorithm_version
)
select m.athlete_id, m.scheduled_date, w.id, w.session_type,
  w.primary_adaptation, coalesce(nullif(m.session ->> 'title', ''), w.primary_adaptation),
  greatest(1, case when coalesce(m.session ->> 'durationMinutes', '') ~ '^\d+$'
    then (m.session ->> 'durationMinutes')::integer else w.duration_minutes end),
  case when coalesce(m.session ->> 'targetLoad', '') ~ '^\d+(\.\d+)?$'
    then (m.session ->> 'targetLoad')::numeric end,
  w.id, w.id,
  case when coalesce(m.session ->> 'adaptationReason', '') <> ''
    then 'modified' else 'unchanged' end,
  'planned',
  jsonb_build_object('source','compatibility_snapshot',
    'snapshot_updated_at',m.updated_at,'legacy_title',m.session ->> 'title',
    'legacy_origin',m.session ->> 'origin'),
  'snapshot-bridge-v1'
from mapped m join public.workout_library w on w.id = m.workout_id
where not exists (
  select 1 from public.planned_sessions p
  where p.athlete_id = m.athlete_id and p.scheduled_date = m.scheduled_date
);
