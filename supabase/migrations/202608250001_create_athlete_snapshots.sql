create table if not exists public.athlete_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null check (schema_version > 0),
  updated_at timestamptz not null,
  source_device text not null check (length(source_device) between 1 and 120),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.athlete_snapshots enable row level security;

revoke all on table public.athlete_snapshots from anon, authenticated;
grant select, insert, update, delete on table public.athlete_snapshots
  to authenticated;

create policy "Athletes read their own snapshot"
  on public.athlete_snapshots for select
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes create their own snapshot"
  on public.athlete_snapshots for insert
  to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes update their own snapshot"
  on public.athlete_snapshots for update
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes delete their own snapshot"
  on public.athlete_snapshots for delete
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
