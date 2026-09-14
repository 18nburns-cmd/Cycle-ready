create table if not exists public.workout_catalogue_variants (
  id text primary key check (id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*-v[1-9][0-9]*$'),
  family text not null,
  name text not null,
  difficulty text not null,
  duration_minutes integer not null check (duration_minutes > 0),
  adaptation_target text not null,
  estimated_recovery_hours integer not null check (estimated_recovery_hours >= 0),
  cadence_low integer,
  cadence_high integer,
  terrain text not null default 'any',
  required_equipment jsonb not null default '["bicycle"]'::jsonb,
  phases jsonb not null default '[]'::jsonb,
  success_criteria jsonb not null default '[]'::jsonb,
  catalogue_version integer not null default 1 check (catalogue_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (cadence_low is null or cadence_high is null or cadence_low <= cadence_high)
);

create table if not exists public.workout_catalogue_steps (
  variant_id text not null references public.workout_catalogue_variants(id) on delete cascade,
  step_index integer not null check (step_index >= 0),
  role text not null check (role in ('warmUp', 'work', 'recovery', 'coolDown')),
  duration_seconds integer not null check (duration_seconds > 0),
  power_low_percent integer not null check (power_low_percent >= 0),
  power_high_percent integer not null,
  repetitions integer not null default 1 check (repetitions > 0),
  cadence_low integer,
  cadence_high integer,
  primary key (variant_id, step_index),
  check (power_low_percent <= power_high_percent),
  check (cadence_low is null or cadence_high is null or cadence_low <= cadence_high)
);

create table if not exists public.workout_catalogue_progressions (
  from_variant_id text not null references public.workout_catalogue_variants(id) on delete cascade,
  to_variant_id text not null references public.workout_catalogue_variants(id) on delete cascade,
  direction text not null check (direction in ('progression', 'regression')),
  primary key (from_variant_id, to_variant_id, direction),
  check (from_variant_id <> to_variant_id)
);

alter table public.workout_catalogue_variants enable row level security;
alter table public.workout_catalogue_steps enable row level security;
alter table public.workout_catalogue_progressions enable row level security;

drop policy if exists workout_catalogue_variants_authenticated_read on public.workout_catalogue_variants;
create policy workout_catalogue_variants_authenticated_read
on public.workout_catalogue_variants for select to authenticated using (true);

drop policy if exists workout_catalogue_steps_authenticated_read on public.workout_catalogue_steps;
create policy workout_catalogue_steps_authenticated_read
on public.workout_catalogue_steps for select to authenticated using (true);

drop policy if exists workout_catalogue_progressions_authenticated_read on public.workout_catalogue_progressions;
create policy workout_catalogue_progressions_authenticated_read
on public.workout_catalogue_progressions for select to authenticated using (true);

revoke all on public.workout_catalogue_variants from anon;
revoke all on public.workout_catalogue_steps from anon;
revoke all on public.workout_catalogue_progressions from anon;
grant select on public.workout_catalogue_variants to authenticated;
grant select on public.workout_catalogue_steps to authenticated;
grant select on public.workout_catalogue_progressions to authenticated;
