create table public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique check (length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios', 'web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.device_push_tokens enable row level security;

create policy device_push_tokens_select_own
  on public.device_push_tokens for select to authenticated
  using (auth.uid() = user_id and public.owns_athlete(athlete_id));

create policy device_push_tokens_insert_own
  on public.device_push_tokens for insert to authenticated
  with check (auth.uid() = user_id and public.owns_athlete(athlete_id));

create policy device_push_tokens_update_own
  on public.device_push_tokens for update to authenticated
  using (auth.uid() = user_id and public.owns_athlete(athlete_id))
  with check (auth.uid() = user_id and public.owns_athlete(athlete_id));

create policy device_push_tokens_delete_own
  on public.device_push_tokens for delete to authenticated
  using (auth.uid() = user_id and public.owns_athlete(athlete_id));

grant select, insert, update, delete on public.device_push_tokens to authenticated;
revoke all on public.device_push_tokens from anon;

create index device_push_tokens_athlete
  on public.device_push_tokens (athlete_id, last_seen_at desc);

comment on table public.device_push_tokens is
  'Per-device FCM registration tokens. Server functions may read them with the service role only.';
