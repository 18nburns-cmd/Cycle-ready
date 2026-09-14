with families(family) as (
  values
    ('recovery'), ('endurance'), ('longendurance'), ('tempo'),
    ('sweetspot'), ('threshold'), ('overunder'), ('vo2max'), ('anaerobic'),
    ('sprint'), ('neuromuscular'), ('cadence'), ('climbingendurance'),
    ('strengthendurance'), ('racesimulation'), ('fatigueresistance')
), links(from_difficulty, to_difficulty, direction) as (
  values
    ('introductory', 'developing', 'progression'),
    ('developing', 'advanced', 'progression'),
    ('advanced', 'developing', 'regression'),
    ('developing', 'introductory', 'regression')
)
insert into public.workout_catalogue_progressions (
  from_variant_id,
  to_variant_id,
  direction
)
select
  family || '-' || from_difficulty || '-v1',
  family || '-' || to_difficulty || '-v1',
  direction
from families cross join links
on conflict (from_variant_id, to_variant_id, direction) do nothing;
