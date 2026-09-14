create table public.workout_delivery_outbox (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  delivery_id uuid not null references public.workout_deliveries(id) on delete cascade,
  provider text not null check (length(trim(provider)) > 0),
  operation text not null check (operation in ('create', 'update', 'delete')),
  idempotency_key text not null,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed', 'failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (athlete_id, idempotency_key)
);

create index workout_delivery_outbox_due
  on public.workout_delivery_outbox (provider, next_attempt_at, created_at)
  where status in ('pending', 'failed');

alter table public.workout_delivery_outbox enable row level security;
create policy workout_delivery_outbox_owner_all on public.workout_delivery_outbox
  for all to authenticated
  using (public.owns_athlete(athlete_id))
  with check (public.owns_athlete(athlete_id));
grant select, insert, update, delete on public.workout_delivery_outbox to authenticated;
