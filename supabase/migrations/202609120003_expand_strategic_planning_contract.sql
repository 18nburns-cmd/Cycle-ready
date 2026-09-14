-- Expand the authoritative planning contract without rewriting historical
-- phases, blocks, capabilities or planned sessions.

alter type public.training_phase
  add value if not exists 'FOUNDATION' before 'BASE';

alter table public.event_demand_profiles
  add column if not exists demand_confidence jsonb not null default '{}'::jsonb,
  add column if not exists model_inputs jsonb not null default '{}'::jsonb;

alter table public.athlete_capabilities
  add column if not exists dimension_confidence jsonb not null default '{}'::jsonb,
  add column if not exists dimension_trends jsonb not null default '{}'::jsonb,
  add column if not exists dimension_evidence_counts jsonb not null default '{}'::jsonb,
  add column if not exists dimension_last_updated jsonb not null default '{}'::jsonb;

alter table public.training_phases
  add column if not exists selection_evidence jsonb not null default '{}'::jsonb;

alter table public.training_blocks
  add column if not exists minimum_duration_days integer not null default 7,
  add column if not exists maximum_duration_days integer not null default 28,
  add column if not exists progression_status text not null default 'CONTINUE',
  add column if not exists completion_criteria jsonb not null default '{}'::jsonb,
  add column if not exists selection_evidence jsonb not null default '{}'::jsonb;

alter table public.weekly_plans
  add column if not exists secondary_adaptation text,
  add column if not exists maintenance_adaptations jsonb not null default '[]'::jsonb,
  add column if not exists adaptation_objectives jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'training_blocks_duration_bounds'
      and conrelid = 'public.training_blocks'::regclass
  ) then
    alter table public.training_blocks
      add constraint training_blocks_duration_bounds check (
        minimum_duration_days > 0
        and maximum_duration_days >= minimum_duration_days
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'training_blocks_progression_status'
      and conrelid = 'public.training_blocks'::regclass
  ) then
    alter table public.training_blocks
      add constraint training_blocks_progression_status check (
        progression_status in
          ('CONTINUE', 'PROGRESS', 'EXTEND', 'END', 'DELOAD', 'REBUILD')
      );
  end if;
end
$$;

comment on column public.athlete_capabilities.dimension_confidence is
  'Per-capability confidence; missing evidence must not be represented as measured fact.';
comment on column public.training_blocks.completion_criteria is
  'Versioned evidence thresholds used to continue, progress, extend, end, deload or rebuild the block.';
comment on column public.weekly_plans.adaptation_objectives is
  'Ordered adaptation objectives selected before individual workouts are assigned.';
