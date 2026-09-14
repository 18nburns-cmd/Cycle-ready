with families(family, adaptation_target, base_minutes, low_power, high_power, terrain) as (
  values
    ('recovery', 'activeRecovery', 35, 40, 55, 'any'),
    ('endurance', 'aerobicEfficiency', 60, 60, 72, 'any'),
    ('longendurance', 'aerobicDurability', 120, 60, 72, 'rolling'),
    ('tempo', 'muscularEndurance', 60, 80, 87, 'rolling'),
    ('sweetspot', 'muscularEndurance', 65, 88, 94, 'rolling'),
    ('threshold', 'thresholdPower', 65, 98, 105, 'flat'),
    ('overunder', 'lactateClearance', 65, 85, 105, 'rolling'),
    ('vo2max', 'maximalAerobicPower', 60, 108, 118, 'sustainedClimb'),
    ('anaerobic', 'anaerobicCapacity', 55, 125, 140, 'flat'),
    ('sprint', 'neuromuscularPower', 50, 150, 200, 'flat'),
    ('neuromuscular', 'neuromuscularPower', 45, 150, 200, 'flat'),
    ('cadence', 'pedallingEconomy', 50, 55, 70, 'flat'),
    ('climbingendurance', 'muscularEndurance', 75, 80, 94, 'sustainedClimb'),
    ('strengthendurance', 'muscularEndurance', 65, 80, 90, 'sustainedClimb'),
    ('racesimulation', 'raceSpecificity', 90, 70, 120, 'rolling'),
    ('fatigueresistance', 'fatigueResistance', 120, 65, 90, 'rolling')
), difficulties(difficulty, level, duration_factor) as (
  values
    ('introductory', 1, 0.80::numeric),
    ('developing', 2, 1.00::numeric),
    ('advanced', 3, 1.20::numeric)
), variants as (
  select
    family || '-' || difficulty || '-v1' as id,
    family,
    initcap(replace(family, 'endurance', ' endurance')) || ' ' || initcap(difficulty) as name,
    difficulty,
    greatest(30, round(base_minutes * duration_factor))::integer as duration_minutes,
    adaptation_target,
    case
      when family = 'recovery' then 8
      when family in ('endurance', 'cadence') then 18 + level * 4
      else 20 + level * 8
    end as estimated_recovery_hours,
    case when family in ('cadence', 'sprint', 'neuromuscular') then 90 else null end as cadence_low,
    case when family in ('cadence', 'sprint', 'neuromuscular') then 120 else null end as cadence_high,
    terrain,
    '["bicycle"]'::jsonb as required_equipment,
    case
      when family = 'recovery' then '["recovery"]'::jsonb
      when family in ('racesimulation', 'fatigueresistance') then '["specific","peak"]'::jsonb
      else '["foundation","build","peak","specific","maintenance"]'::jsonb
    end as phases,
    jsonb_build_array(jsonb_build_object(
      'metric', 'work_interval_power_completion',
      'minimum', 0.85,
      'maximum', 1.15,
      'unit', 'ratio'
    )) as success_criteria,
    low_power,
    high_power,
    level
  from families cross join difficulties
), upserted as (
  insert into public.workout_catalogue_variants (
    id, family, name, difficulty, duration_minutes, adaptation_target,
    estimated_recovery_hours, cadence_low, cadence_high, terrain,
    required_equipment, phases, success_criteria, catalogue_version
  )
  select id, family, name, difficulty, duration_minutes, adaptation_target,
    estimated_recovery_hours, cadence_low, cadence_high, terrain,
    required_equipment, phases, success_criteria, 1
  from variants
  on conflict (id) do update set
    name = excluded.name,
    duration_minutes = excluded.duration_minutes,
    adaptation_target = excluded.adaptation_target,
    estimated_recovery_hours = excluded.estimated_recovery_hours,
    cadence_low = excluded.cadence_low,
    cadence_high = excluded.cadence_high,
    terrain = excluded.terrain,
    required_equipment = excluded.required_equipment,
    phases = excluded.phases,
    success_criteria = excluded.success_criteria,
    catalogue_version = excluded.catalogue_version,
    updated_at = now()
  returning id
)
insert into public.workout_catalogue_steps (
  variant_id, step_index, role, duration_seconds, power_low_percent,
  power_high_percent, repetitions, cadence_low, cadence_high
)
select variants.id, steps.step_index, steps.role, steps.duration_seconds,
  steps.power_low_percent, steps.power_high_percent, steps.repetitions,
  steps.cadence_low, steps.cadence_high
from variants
cross join lateral (
  values
    (0, 'warmUp', 600, 45, 70, 1, null::integer, null::integer),
    (1, 'work', greatest(60, ((duration_minutes - 25) * 60 / greatest(1, level + 1))), low_power, high_power, greatest(1, level + 1), cadence_low, cadence_high),
    (2, 'recovery', 180, 40, 55, greatest(1, level), null::integer, null::integer),
    (3, 'coolDown', 600, 40, 55, 1, null::integer, null::integer)
) steps(step_index, role, duration_seconds, power_low_percent, power_high_percent, repetitions, cadence_low, cadence_high)
on conflict (variant_id, step_index) do update set
  role = excluded.role,
  duration_seconds = excluded.duration_seconds,
  power_low_percent = excluded.power_low_percent,
  power_high_percent = excluded.power_high_percent,
  repetitions = excluded.repetitions,
  cadence_low = excluded.cadence_low,
  cadence_high = excluded.cadence_high;
