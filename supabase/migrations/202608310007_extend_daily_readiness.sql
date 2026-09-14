alter table public.daily_readiness
  add column if not exists recovery_score numeric(5,2)
    check (recovery_score between 0 and 100),
  add column if not exists fatigue_score numeric(5,2)
    check (fatigue_score between 0 and 100),
  add column if not exists reason_codes text[] not null default '{}',
  add column if not exists source_references jsonb not null default '{}'::jsonb;

create index if not exists daily_readiness_latest
  on public.daily_readiness (athlete_id, readiness_date desc);

create unique index if not exists coaching_state_snapshot_readiness_version
  on public.coaching_state_snapshots (readiness_id, algorithm_version);
