create table if not exists public.activity_sample_chunks (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id text not null,
  chunk_index integer not null check (chunk_index >= 0),
  sample_count integer not null check (sample_count between 1 and 500),
  first_elapsed_seconds integer not null check (first_elapsed_seconds >= 0),
  last_elapsed_seconds integer not null check (last_elapsed_seconds >= first_elapsed_seconds),
  content_hash text not null check (length(content_hash) = 64),
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, activity_id, chunk_index)
);

create index if not exists activity_sample_chunks_lookup
  on public.activity_sample_chunks (user_id, activity_id, chunk_index);

alter table public.activity_sample_chunks enable row level security;

revoke all on table public.activity_sample_chunks from anon, authenticated;
grant select, insert, update, delete on table public.activity_sample_chunks
  to authenticated;

create policy "Athletes read their activity sample chunks"
  on public.activity_sample_chunks for select
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes create their activity sample chunks"
  on public.activity_sample_chunks for insert
  to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes update their activity sample chunks"
  on public.activity_sample_chunks for update
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy "Athletes delete their activity sample chunks"
  on public.activity_sample_chunks for delete
  to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
