-- Server-authoritative, recalculable training metrics and physiological
-- baselines. Source facts remain untouched when an algorithm is re-run.

create table public.daily_training_metrics (
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  metric_date date not null,
  daily_load numeric(8,2) not null check (daily_load >= 0),
  load_7_day numeric(9,2) not null check (load_7_day >= 0),
  load_28_day numeric(9,2) not null check (load_28_day >= 0),
  chronic_training_load numeric(8,2) not null check (chronic_training_load >= 0),
  acute_training_load numeric(8,2) not null check (acute_training_load >= 0),
  training_stress_balance numeric(8,2) not null,
  weekly_ctl_ramp numeric(8,2) not null,
  source_activity_ids uuid[] not null default '{}',
  data_confidence numeric(4,3) not null check (data_confidence between 0 and 1),
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  primary key (athlete_id, metric_date, algorithm_version)
);
create index daily_training_metrics_latest
  on public.daily_training_metrics (athlete_id, metric_date desc);

create table public.athlete_metric_baselines (
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  baseline_date date not null,
  hrv_baseline_ms numeric(7,2),
  resting_hr_baseline numeric(5,2),
  hrv_sample_count integer not null default 0 check (hrv_sample_count >= 0),
  resting_hr_sample_count integer not null default 0 check (resting_hr_sample_count >= 0),
  source_observation_ids uuid[] not null default '{}',
  data_confidence numeric(4,3) not null check (data_confidence between 0 and 1),
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  primary key (athlete_id, baseline_date, algorithm_version)
);

alter table public.metric_calculation_runs
  add column if not exists idempotency_key text;
update public.metric_calculation_runs
set idempotency_key = id::text
where idempotency_key is null;
alter table public.metric_calculation_runs
  alter column idempotency_key set not null,
  add constraint metric_calculation_runs_idempotency
    unique (athlete_id, metric_type, idempotency_key);

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'daily_training_metrics', 'athlete_metric_baselines'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.owns_athlete(athlete_id))',
      table_name || '_owner_read', table_name
    );
  end loop;
end $$;

grant select on public.daily_training_metrics,
  public.athlete_metric_baselines to authenticated;
