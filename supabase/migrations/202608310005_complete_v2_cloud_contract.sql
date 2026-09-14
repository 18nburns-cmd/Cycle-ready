-- Complete the Adaptive Cycling Coach v2 cloud contract without removing the
-- live compatibility tables introduced by earlier migrations.

create table public.event_demand_profiles (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  goal_id uuid not null references public.goals(id) on delete cascade,
  demand_scores jsonb not null,
  limiting_factors text[] not null default '{}',
  evidence jsonb not null default '{}'::jsonb,
  confidence numeric(4,3) not null check (confidence between 0 and 1),
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  unique (goal_id, algorithm_version)
);

create table public.athlete_capabilities (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  capability_date date not null,
  capability_scores jsonb not null,
  confidence numeric(4,3) not null check (confidence between 0 and 1),
  evidence_count integer not null default 0 check (evidence_count >= 0),
  evidence jsonb not null default '{}'::jsonb,
  last_evidence_at timestamptz,
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  unique (athlete_id, capability_date, algorithm_version)
);

create table public.training_phases (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  phase public.training_phase not null,
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  purpose text not null,
  primary_adaptation text not null,
  secondary_adaptation text,
  status text not null default 'planned',
  algorithm_version text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.training_blocks
  add column if not exists training_phase_id uuid
    references public.training_phases(id) on delete set null,
  add column if not exists purpose text,
  add column if not exists algorithm_version text not null default 'legacy-v1';

create table public.weekly_plans (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  training_block_id uuid not null references public.training_blocks(id) on delete cascade,
  week_start date not null,
  purpose text not null,
  primary_adaptation text not null,
  planned_load numeric(8,2) check (planned_load >= 0),
  recovery_week boolean not null default false,
  source_evidence jsonb not null default '{}'::jsonb,
  algorithm_version text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (athlete_id, week_start)
);

alter table public.planned_sessions
  add column if not exists weekly_plan_id uuid
    references public.weekly_plans(id) on delete set null,
  add column if not exists source_evidence jsonb not null default '{}'::jsonb,
  add column if not exists algorithm_version text not null default 'legacy-v1';

-- The source table remains named wellness for compatibility. This
-- security-invoker view exposes the v2 contract name without duplicating facts.
create view public.wellness_observations
with (security_invoker = true)
as select * from public.wellness;

create table public.daily_wellness_resolved (
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  recorded_date date not null,
  source_observation_id uuid not null references public.wellness(id) on delete cascade,
  hrv_ms numeric(7,2),
  resting_hr numeric(5,2),
  sleep_minutes integer,
  sleep_quality numeric(3,1),
  fatigue numeric(3,1),
  soreness numeric(3,1),
  stress numeric(3,1),
  motivation numeric(3,1),
  weight_kg numeric(5,2),
  illness_flag boolean not null,
  injury_or_pain_flag boolean not null,
  source text not null,
  source_attribution jsonb not null,
  algorithm_version text not null,
  resolved_at timestamptz not null default now(),
  primary key (athlete_id, recorded_date)
);

create table public.coaching_state_snapshots (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  effective_at timestamptz not null,
  athlete_state text not null,
  readiness_id uuid references public.daily_readiness(id) on delete set null,
  active_goal_id uuid references public.goals(id) on delete set null,
  active_block_id uuid references public.training_blocks(id) on delete set null,
  current_session_id uuid references public.planned_sessions(id) on delete set null,
  state_payload jsonb not null,
  evidence jsonb not null default '{}'::jsonb,
  confidence numeric(4,3) not null check (confidence between 0 and 1),
  algorithm_version text not null,
  created_at timestamptz not null default now()
);
create index coaching_state_snapshots_latest
  on public.coaching_state_snapshots (athlete_id, effective_at desc);

create table public.metric_calculation_runs (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  metric_type text not null,
  input_window_start timestamptz,
  input_window_end timestamptz,
  source_references jsonb not null default '[]'::jsonb,
  output_references jsonb not null default '[]'::jsonb,
  algorithm_version text not null,
  status text not null,
  error_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table public.integration_sync_runs (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  integration_id uuid references public.integrations(id) on delete set null,
  provider text not null,
  idempotency_key text not null,
  trigger_type text not null,
  requested_window jsonb not null default '{}'::jsonb,
  imported_counts jsonb not null default '{}'::jsonb,
  status text not null,
  error_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (athlete_id, provider, idempotency_key)
);

create table public.athlete_feedback (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  planned_session_id uuid references public.planned_sessions(id) on delete set null,
  activity_id uuid references public.activities(id) on delete set null,
  feedback_type text not null,
  rating numeric(3,1) check (rating between 0 and 10),
  response jsonb not null default '{}'::jsonb,
  source text not null,
  recorded_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create trigger training_phases_set_updated_at before update on public.training_phases
  for each row execute function public.set_updated_at();
create trigger weekly_plans_set_updated_at before update on public.weekly_plans
  for each row execute function public.set_updated_at();

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'event_demand_profiles', 'athlete_capabilities', 'training_phases',
    'weekly_plans', 'daily_wellness_resolved', 'coaching_state_snapshots',
    'metric_calculation_runs', 'integration_sync_runs', 'athlete_feedback',
    'notifications'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.owns_athlete(athlete_id)) with check (public.owns_athlete(athlete_id))',
      table_name || '_owner_all', table_name
    );
  end loop;
end $$;

grant select on public.wellness_observations to authenticated;
grant select on public.event_demand_profiles,
  public.athlete_capabilities, public.training_phases, public.weekly_plans,
  public.daily_wellness_resolved, public.coaching_state_snapshots,
  public.metric_calculation_runs, public.integration_sync_runs,
  public.athlete_feedback, public.notifications to authenticated;
grant insert on public.athlete_feedback to authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Materialize the current winning wellness source so server jobs read a stable,
-- attributable input. Future ingestion jobs rerun the same deterministic upsert.
insert into public.daily_wellness_resolved (
  athlete_id, recorded_date, source_observation_id, hrv_ms, resting_hr,
  sleep_minutes, sleep_quality, fatigue, soreness, stress, motivation,
  weight_kg, illness_flag, injury_or_pain_flag, source, source_attribution,
  algorithm_version
)
select athlete_id, recorded_date, id, hrv_ms, resting_hr, sleep_minutes,
  sleep_quality, fatigue, soreness, stress, motivation, weight_kg, illness_flag,
  injury_or_pain_flag, source,
  jsonb_build_object('observation_id', id, 'source', source),
  'wellness-resolution-v1'
from public.resolved_daily_wellness
on conflict (athlete_id, recorded_date) do update set
  source_observation_id = excluded.source_observation_id,
  hrv_ms = excluded.hrv_ms,
  resting_hr = excluded.resting_hr,
  sleep_minutes = excluded.sleep_minutes,
  sleep_quality = excluded.sleep_quality,
  fatigue = excluded.fatigue,
  soreness = excluded.soreness,
  stress = excluded.stress,
  motivation = excluded.motivation,
  weight_kg = excluded.weight_kg,
  illness_flag = excluded.illness_flag,
  injury_or_pain_flag = excluded.injury_or_pain_flag,
  source = excluded.source,
  source_attribution = excluded.source_attribution,
  algorithm_version = excluded.algorithm_version,
  resolved_at = now();
