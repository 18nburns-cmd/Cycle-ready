drop index if exists public.activities_external_identity;
create unique index activities_external_identity
  on public.activities (athlete_id, source, external_activity_id);

