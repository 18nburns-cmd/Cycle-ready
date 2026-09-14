alter table public.daily_coaching_recommendations
  add column if not exists evidence_fingerprint text;

alter table public.daily_coaching_recommendations
  add constraint daily_coaching_evidence_fingerprint_format
  check (evidence_fingerprint is null or evidence_fingerprint ~ '^[0-9a-f]{64}$');
