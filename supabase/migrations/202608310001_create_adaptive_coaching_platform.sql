-- CycleReady canonical cloud model.
-- Source facts, recalculable metrics, and coaching state are deliberately
-- separated. Existing snapshot tables remain as a migration bridge only.

create extension if not exists pgcrypto;

create type public.goal_priority as enum ('A', 'B', 'C');
create type public.training_phase as enum
  ('BASE', 'BUILD', 'SPECIALTY', 'TAPER', 'RECOVERY', 'TRANSITION');
create type public.session_outcome as enum
  ('EXCEEDED', 'ACHIEVED', 'PARTIALLY_ACHIEVED', 'NOT_ACHIEVED', 'ACHIEVED_HIGH_COST');

create table public.athletes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  date_of_birth date,
  sex text,
  body_mass_kg numeric(5,2) check (body_mass_kg between 30 and 250),
  current_ftp integer check (current_ftp between 40 and 800),
  maximum_hr integer check (maximum_hr between 80 and 240),
  resting_hr_baseline numeric(5,2) check (resting_hr_baseline between 20 and 150),
  hrv_baseline_ms numeric(7,2) check (hrv_baseline_ms > 0),
  experience_level text not null default 'intermediate',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.athlete_availability (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7),
  available boolean not null default true,
  maximum_duration_minutes integer check (maximum_duration_minutes between 0 and 1440),
  preferred_training_time time,
  unique (athlete_id, day_of_week)
);

create table public.integrations (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  provider text not null check (length(trim(provider)) between 1 and 40),
  provider_athlete_id text,
  connection_status text not null default 'disconnected',
  last_sync_at timestamptz,
  sync_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (athlete_id, provider)
);
comment on table public.integrations is
  'Connection metadata only. Provider secrets belong in server-side secret storage.';

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  external_activity_id text,
  source text not null,
  started_at timestamptz not null,
  sport text not null default 'cycling',
  duration_seconds integer not null check (duration_seconds >= 0),
  moving_time_seconds integer check (moving_time_seconds >= 0),
  distance_metres numeric(12,2) check (distance_metres >= 0),
  elevation_metres numeric(10,2) check (elevation_metres >= 0),
  average_power integer check (average_power >= 0),
  normalized_power integer check (normalized_power >= 0),
  maximum_power integer check (maximum_power >= 0),
  average_hr integer check (average_hr between 20 and 250),
  maximum_hr integer check (maximum_hr between 20 and 250),
  average_cadence numeric(6,2) check (average_cadence >= 0),
  kilojoules numeric(12,2) check (kilojoules >= 0),
  training_load numeric(8,2) check (training_load >= 0),
  rpe numeric(3,1) check (rpe between 0 and 10),
  perceived_leg_fatigue numeric(3,1) check (perceived_leg_fatigue between 0 and 10),
  notes text,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index activities_external_identity
  on public.activities (athlete_id, source, external_activity_id)
  where external_activity_id is not null;
create index activities_athlete_started_at
  on public.activities (athlete_id, started_at desc);

create table public.activity_intervals (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  interval_number integer not null check (interval_number >= 0),
  interval_type text not null,
  start_offset_seconds integer not null check (start_offset_seconds >= 0),
  duration_seconds integer not null check (duration_seconds > 0),
  average_power integer check (average_power >= 0),
  normalized_power integer check (normalized_power >= 0),
  average_hr integer check (average_hr between 20 and 250),
  maximum_hr integer check (maximum_hr between 20 and 250),
  average_cadence numeric(6,2) check (average_cadence >= 0),
  target_power integer check (target_power >= 0),
  completion_status text,
  source_payload jsonb not null default '{}'::jsonb,
  unique (activity_id, interval_number)
);

create table public.wellness (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  recorded_date date not null,
  hrv_ms numeric(7,2) check (hrv_ms > 0),
  resting_hr numeric(5,2) check (resting_hr between 20 and 150),
  sleep_minutes integer check (sleep_minutes between 0 and 1440),
  sleep_quality numeric(3,1) check (sleep_quality between 0 and 10),
  fatigue numeric(3,1) check (fatigue between 0 and 10),
  soreness numeric(3,1) check (soreness between 0 and 10),
  stress numeric(3,1) check (stress between 0 and 10),
  motivation numeric(3,1) check (motivation between 0 and 10),
  weight_kg numeric(5,2) check (weight_kg between 30 and 250),
  illness_flag boolean not null default false,
  injury_or_pain_flag boolean not null default false,
  source text not null,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (athlete_id, recorded_date, source)
);
create index wellness_athlete_date on public.wellness (athlete_id, recorded_date desc);

create table public.ftp_history (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  effective_date date not null,
  ftp integer not null check (ftp between 40 and 800),
  source text not null,
  confidence numeric(4,3) check (confidence between 0 and 1),
  test_type text,
  created_at timestamptz not null default now(),
  unique (athlete_id, effective_date, source)
);

create table public.weight_history (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  measured_at timestamptz not null,
  weight_kg numeric(5,2) not null check (weight_kg between 30 and 250),
  source text not null,
  created_at timestamptz not null default now(),
  unique (athlete_id, measured_at, source)
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  name text not null,
  event_date date not null,
  event_type text not null,
  priority public.goal_priority not null default 'C',
  distance_metres numeric(12,2) check (distance_metres >= 0),
  elevation_metres numeric(10,2) check (elevation_metres >= 0),
  expected_duration_seconds integer check (expected_duration_seconds > 0),
  target_performance text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.training_blocks (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  phase public.training_phase not null,
  primary_adaptation text not null,
  secondary_adaptation text,
  maintenance_adaptations jsonb not null default '[]'::jsonb,
  planned_load numeric(8,2) check (planned_load >= 0),
  status text not null default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workout_library (
  id text primary key check (id ~ '^[A-Z0-9_]+$'),
  session_type text not null,
  difficulty_level integer not null check (difficulty_level between 1 and 10),
  intended_phases public.training_phase[] not null,
  primary_adaptation text not null,
  secondary_adaptation text,
  duration_minutes integer not null check (duration_minutes > 0),
  interval_structure jsonb not null,
  intensity_targets jsonb not null,
  success_metrics jsonb not null,
  progression_rules jsonb not null default '{}'::jsonb,
  regression_alternatives text[] not null default '{}',
  library_version text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.planned_sessions (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  scheduled_date date not null,
  workout_library_id text references public.workout_library(id),
  training_block_id uuid references public.training_blocks(id) on delete set null,
  session_type text not null,
  primary_adaptation text not null,
  secondary_adaptation text,
  purpose text not null,
  planned_duration_minutes integer not null check (planned_duration_minutes > 0),
  planned_load numeric(8,2) check (planned_load >= 0),
  original_workout_id text references public.workout_library(id),
  current_workout_id text references public.workout_library(id),
  adaptation_status text not null default 'unchanged',
  completion_status text not null default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index planned_sessions_calendar
  on public.planned_sessions (athlete_id, scheduled_date);

create table public.session_analysis (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  planned_session_id uuid references public.planned_sessions(id) on delete set null,
  session_outcome public.session_outcome not null,
  stimulus_achievement_score numeric(5,2) check (stimulus_achievement_score between 0 and 100),
  recovery_cost_score numeric(5,2) check (recovery_cost_score between 0 and 100),
  durability_score numeric(5,2) check (durability_score between 0 and 100),
  pw_hr_decoupling numeric(7,3),
  power_fade numeric(7,3),
  interval_completion numeric(5,2) check (interval_completion between 0 and 100),
  target_power_achievement numeric(5,2) check (target_power_achievement between 0 and 100),
  rpe numeric(3,1) check (rpe between 0 and 10),
  adaptation_achieved boolean not null default false,
  absorbed boolean,
  interpretation text not null,
  confidence numeric(4,3) not null check (confidence between 0 and 1),
  analysis_version text not null,
  analysed_at timestamptz not null default now(),
  unique (activity_id, analysis_version)
);

create table public.daily_readiness (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  readiness_date date not null,
  readiness_score numeric(5,2) not null check (readiness_score between 0 and 100),
  athlete_state text not null,
  fatigue_risk text not null,
  data_confidence numeric(4,3) not null check (data_confidence between 0 and 1),
  contributing_metrics jsonb not null,
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  unique (athlete_id, readiness_date, algorithm_version)
);

create table public.adaptive_decisions (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  created_at timestamptz not null default now(),
  affected_session_id uuid references public.planned_sessions(id) on delete set null,
  original_workout jsonb not null,
  replacement_workout jsonb,
  adaptation_level smallint not null check (adaptation_level between 0 and 3),
  decision text not null,
  reason_codes text[] not null,
  evidence jsonb not null default '{}'::jsonb,
  explanation text not null,
  confidence numeric(4,3) not null check (confidence between 0 and 1),
  coaching_model_version text not null
);
create index adaptive_decisions_history
  on public.adaptive_decisions (athlete_id, created_at desc);

-- Prevent accidental historical rewrites. Corrections are appended as a new
-- versioned record, keeping every coaching action auditable.
create function public.reject_adaptive_decision_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'adaptive decisions are append-only';
end;
$$;
create trigger adaptive_decisions_append_only
  before update or delete on public.adaptive_decisions
  for each row execute function public.reject_adaptive_decision_mutation();

create function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger athletes_set_updated_at before update on public.athletes
  for each row execute function public.set_updated_at();
create trigger integrations_set_updated_at before update on public.integrations
  for each row execute function public.set_updated_at();
create trigger activities_set_updated_at before update on public.activities
  for each row execute function public.set_updated_at();
create trigger wellness_set_updated_at before update on public.wellness
  for each row execute function public.set_updated_at();
create trigger goals_set_updated_at before update on public.goals
  for each row execute function public.set_updated_at();
create trigger training_blocks_set_updated_at before update on public.training_blocks
  for each row execute function public.set_updated_at();
create trigger workout_library_set_updated_at before update on public.workout_library
  for each row execute function public.set_updated_at();
create trigger planned_sessions_set_updated_at before update on public.planned_sessions
  for each row execute function public.set_updated_at();

-- RLS ownership helper. The caller's JWT identity must own the athlete.
create function public.owns_athlete(target_athlete_id uuid)
returns boolean language sql stable security definer
set search_path = '' as $$
  select exists (
    select 1 from public.athletes
    where id = target_athlete_id and user_id = (select auth.uid())
  );
$$;
revoke all on function public.owns_athlete(uuid) from public;
grant execute on function public.owns_athlete(uuid) to authenticated;

alter table public.athletes enable row level security;
create policy athletes_owner_all on public.athletes for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'athlete_availability', 'integrations', 'activities', 'activity_intervals',
    'wellness', 'ftp_history', 'weight_history', 'goals', 'training_blocks',
    'planned_sessions', 'session_analysis', 'daily_readiness', 'adaptive_decisions'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.owns_athlete(athlete_id)) with check (public.owns_athlete(athlete_id))',
      table_name || '_owner_all', table_name
    );
  end loop;
end $$;

alter table public.workout_library enable row level security;
create policy workout_library_authenticated_read on public.workout_library
  for select to authenticated using (active = true);

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on public.athletes,
  public.athlete_availability, public.integrations, public.activities,
  public.activity_intervals, public.wellness, public.ftp_history,
  public.weight_history, public.goals, public.training_blocks,
  public.planned_sessions, public.session_analysis, public.daily_readiness
  to authenticated;
grant select, insert on public.adaptive_decisions to authenticated;
grant select on public.workout_library to authenticated;

