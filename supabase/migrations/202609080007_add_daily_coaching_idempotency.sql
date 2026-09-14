alter table public.daily_coaching_recommendations
  add constraint daily_coaching_recommendations_athlete_day_unique
  unique (athlete_id, coaching_date);

create unique index daily_coaching_recommendations_idempotency_key_unique
  on public.daily_coaching_recommendations (idempotency_key);
