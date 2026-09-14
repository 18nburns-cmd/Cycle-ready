alter type public.training_phase add value if not exists 'PEAK' after 'SPECIALTY';

create unique index if not exists training_phases_version_identity
  on public.training_phases
    (athlete_id, goal_id, start_date, end_date, phase, algorithm_version);

create unique index if not exists training_blocks_version_identity
  on public.training_blocks
    (athlete_id, goal_id, start_date, end_date, phase, algorithm_version);
