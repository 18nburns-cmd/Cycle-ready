create table public.nutrition_entries (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  recorded_at timestamptz not null,
  label text not null default 'Food',
  calories integer not null default 0 check (calories >= 0),
  carbohydrate_grams numeric(8,2) not null default 0 check (carbohydrate_grams >= 0),
  protein_grams numeric(8,2) not null default 0 check (protein_grams >= 0),
  fat_grams numeric(8,2) not null default 0 check (fat_grams >= 0),
  water_millilitres integer not null default 0 check (water_millilitres >= 0),
  source text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index nutrition_entries_athlete_time
  on public.nutrition_entries (athlete_id, recorded_at desc);

create table public.daily_nutrition_targets (
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  target_date date not null,
  calories integer not null check (calories > 0),
  carbohydrate_grams integer not null check (carbohydrate_grams >= 0),
  protein_grams integer not null check (protein_grams >= 0),
  fat_grams integer not null check (fat_grams >= 0),
  water_millilitres integer not null check (water_millilitres > 0),
  evidence jsonb not null default '{}'::jsonb,
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  primary key (athlete_id, target_date, algorithm_version)
);

create trigger nutrition_entries_set_updated_at before update on public.nutrition_entries
  for each row execute function public.set_updated_at();

alter table public.nutrition_entries enable row level security;
create policy nutrition_entries_owner_all on public.nutrition_entries
  for all to authenticated using (public.owns_athlete(athlete_id))
  with check (public.owns_athlete(athlete_id));
alter table public.daily_nutrition_targets enable row level security;
create policy daily_nutrition_targets_owner_read on public.daily_nutrition_targets
  for select to authenticated using (public.owns_athlete(athlete_id));

grant select, insert, update, delete on public.nutrition_entries to authenticated;
grant select on public.daily_nutrition_targets to authenticated;
