create table public.daily_coaching_recommendations (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  coaching_date date not null,
  idempotency_key text not null,
  status text not null check (status in ('COMPLETED', 'FALLBACK', 'FAILED')),
  input_snapshot jsonb not null,
  evidence_snapshot jsonb not null,
  recommendation jsonb not null,
  model_version text not null,
  generated_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index daily_coaching_recommendations_history
  on public.daily_coaching_recommendations (athlete_id, coaching_date desc, generated_at desc);

alter table public.daily_coaching_recommendations enable row level security;
create policy daily_coaching_recommendations_owner_read
  on public.daily_coaching_recommendations for select to authenticated
  using (public.owns_athlete(athlete_id));

grant select on public.daily_coaching_recommendations to authenticated;
