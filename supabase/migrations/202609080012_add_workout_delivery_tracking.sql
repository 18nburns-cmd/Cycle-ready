create table public.workout_deliveries (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  planned_session_id uuid not null references public.planned_sessions(id) on delete cascade,
  provider text not null check (length(trim(provider)) > 0),
  external_workout_id text,
  desired_content_hash text not null check (desired_content_hash ~ '^[0-9a-f]{64}$'),
  acknowledged_content_hash text check (acknowledged_content_hash ~ '^[0-9a-f]{64}$'),
  desired_version integer not null default 1 check (desired_version > 0),
  acknowledged_version integer check (
    acknowledged_version is null or
    (acknowledged_version > 0 and acknowledged_version <= desired_version)
  ),
  delivery_status text not null default 'pending' check (delivery_status in (
    'pending', 'delivered', 'updated', 'deleted', 'failed', 'externally_diverged'
  )),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_attempt_at timestamptz,
  failure_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (planned_session_id, provider)
);

create index workout_deliveries_attention
  on public.workout_deliveries (athlete_id, delivery_status, updated_at desc)
  where delivery_status in ('failed', 'externally_diverged');

create trigger workout_deliveries_set_updated_at
  before update on public.workout_deliveries
  for each row execute function public.set_updated_at();

alter table public.workout_deliveries enable row level security;
create policy workout_deliveries_owner_all on public.workout_deliveries
  for all to authenticated
  using (public.owns_athlete(athlete_id))
  with check (public.owns_athlete(athlete_id));

grant select, insert, update, delete on public.workout_deliveries to authenticated;
