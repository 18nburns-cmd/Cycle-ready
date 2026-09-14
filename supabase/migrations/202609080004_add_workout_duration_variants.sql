alter table public.workout_catalogue_variants
add column if not exists duration_class text not null default 'standard'
check (duration_class in ('short', 'standard', 'extended'));

with duration_variants(duration_class, duration_factor) as (
  values ('short', 0.70::numeric), ('extended', 1.30::numeric)
), inserted as (
  insert into public.workout_catalogue_variants (
    id, family, name, difficulty, duration_minutes, duration_class,
    adaptation_target, estimated_recovery_hours, cadence_low, cadence_high,
    terrain, required_equipment, phases, success_criteria, catalogue_version
  )
  select
    regexp_replace(source.id, '-v1$', '-' || duration_variants.duration_class || '-v1'),
    source.family,
    source.name || ' · ' || initcap(duration_variants.duration_class),
    source.difficulty,
    greatest(25, round(source.duration_minutes * duration_variants.duration_factor))::integer,
    duration_variants.duration_class,
    source.adaptation_target,
    greatest(4, round(source.estimated_recovery_hours * duration_variants.duration_factor))::integer,
    source.cadence_low,
    source.cadence_high,
    source.terrain,
    source.required_equipment,
    source.phases,
    source.success_criteria,
    source.catalogue_version
  from public.workout_catalogue_variants source
  cross join duration_variants
  where source.duration_class = 'standard'
    and source.id ~ '^[a-z]+-(introductory|developing|advanced)-v1$'
  on conflict (id) do update set
    duration_minutes = excluded.duration_minutes,
    estimated_recovery_hours = excluded.estimated_recovery_hours,
    updated_at = now()
  returning id
)
insert into public.workout_catalogue_steps (
  variant_id, step_index, role, duration_seconds, power_low_percent,
  power_high_percent, repetitions, cadence_low, cadence_high
)
select
  regexp_replace(step.variant_id, '-v1$', '-' || duration_variants.duration_class || '-v1'),
  step.step_index,
  step.role,
  case when step.role = 'work'
    then greatest(30, round(step.duration_seconds * duration_variants.duration_factor))::integer
    else step.duration_seconds
  end,
  step.power_low_percent,
  step.power_high_percent,
  step.repetitions,
  step.cadence_low,
  step.cadence_high
from public.workout_catalogue_steps step
join public.workout_catalogue_variants source on source.id = step.variant_id
cross join duration_variants
where source.duration_class = 'standard'
  and source.id ~ '^[a-z]+-(introductory|developing|advanced)-v1$'
on conflict (variant_id, step_index) do update set
  duration_seconds = excluded.duration_seconds;
