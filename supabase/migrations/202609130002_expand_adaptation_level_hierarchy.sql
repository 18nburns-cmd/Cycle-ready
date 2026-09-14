-- The adaptation-first engine uses the complete intent-preserving hierarchy:
-- 0 keep, 1-2 reduce within family, 3 same-adaptation substitution,
-- 4 tempo/sweet-spot, 5 endurance, 6 recovery and 7 rest/other fallback.
alter table public.adaptive_decisions
  drop constraint if exists adaptive_decisions_adaptation_level_check;

alter table public.adaptive_decisions
  add constraint adaptive_decisions_adaptation_level_check
  check (adaptation_level between 0 and 7);
