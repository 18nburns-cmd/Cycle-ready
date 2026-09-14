-- Drift serializes local calendar midnights as epoch milliseconds. Preserve
-- the athlete's Europe/London calendar date instead of truncating the UTC
-- instant, which is one day earlier during British Summer Time.

with snapshot_goals as (
  select a.id athlete_id, g.value goal,
    (to_timestamp((g.value ->> 'eventDate')::numeric / 1000)
      at time zone 'Europe/London')::date event_date
  from public.athlete_snapshots s
  join public.athletes a on a.user_id = s.user_id
  cross join lateral jsonb_array_elements(s.payload -> 'eventGoals') g(value)
  where jsonb_typeof(g.value -> 'eventDate') = 'number'
)
update public.goals target
set event_date = source.event_date,
    updated_at = now()
from snapshot_goals source
where target.athlete_id = source.athlete_id
  and target.name = (source.goal ->> 'name')
  and target.notes like 'Migrated from compatibility snapshot%';

with snapshot_sessions as (
  select a.id athlete_id, p.value session,
    (to_timestamp((p.value ->> 'day')::numeric / 1000)
      at time zone 'UTC')::date old_scheduled_date,
    (to_timestamp((p.value ->> 'day')::numeric / 1000)
      at time zone 'Europe/London')::date scheduled_date
  from public.athlete_snapshots s
  join public.athletes a on a.user_id = s.user_id
  cross join lateral jsonb_array_elements(s.payload -> 'plannedSessions') p(value)
  where jsonb_typeof(p.value -> 'day') = 'number'
)
update public.planned_sessions target
set scheduled_date = source.scheduled_date,
    updated_at = now()
from snapshot_sessions source
where target.athlete_id = source.athlete_id
  and target.source_evidence ->> 'source' = 'compatibility_snapshot'
  and target.scheduled_date = source.old_scheduled_date
  and target.source_evidence ->> 'legacy_title' = source.session ->> 'title';
