alter table public.goals
  add column if not exists client_goal_id integer;

create unique index if not exists goals_athlete_client_identity
  on public.goals (athlete_id, client_goal_id);

comment on column public.goals.client_goal_id is
  'Stable on-device event identity used for idempotent multi-event synchronization.';
