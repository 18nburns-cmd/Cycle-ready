alter table public.session_analysis
  add column if not exists analysis_status text not null default 'provisional',
  add column if not exists failure_reasons text[] not null default '{}',
  add column if not exists next_session_action text not null default 'HOLD',
  add column if not exists source_references jsonb not null default '{}'::jsonb,
  add column if not exists component_scores jsonb not null default '{}'::jsonb,
  add column if not exists recovery_updated_at timestamptz;

create index if not exists session_analysis_pending_recovery
  on public.session_analysis (athlete_id, analysed_at)
  where analysis_status = 'provisional';
