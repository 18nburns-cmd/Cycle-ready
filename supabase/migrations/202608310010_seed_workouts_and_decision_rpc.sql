alter table public.athletes
  add column if not exists coaching_constraints jsonb not null default
    '{"equipment":["outdoor_bike"],"sleep_target_minutes":480}'::jsonb;

alter table public.adaptive_decisions
  add column if not exists decision_key text;
create unique index if not exists adaptive_decisions_decision_key
  on public.adaptive_decisions (athlete_id, decision_key);

insert into public.workout_library (
  id, session_type, difficulty_level, intended_phases, primary_adaptation,
  secondary_adaptation, duration_minutes, interval_structure,
  intensity_targets, success_metrics, progression_rules,
  regression_alternatives, library_version
) values
  ('RECOVERY_30', 'recovery', 1, array['BASE','BUILD','SPECIALTY','PEAK','TAPER','RECOVERY']::public.training_phase[], 'recovery', null, 30, '{"equipment":["outdoor_bike","indoor_trainer"],"segments":[{"minutes":30,"zone":"Z1"}]}', '{"ftp_percent":[40,55]}', '{"max_rpe":3}', '{"progress_to":"ENDURANCE_45"}', '{}', 'v2.0.0'),
  ('ENDURANCE_45', 'endurance', 2, array['BASE','BUILD','SPECIALTY','PEAK','TAPER','RECOVERY']::public.training_phase[], 'aerobic_endurance', 'recovery_between_efforts', 45, '{"equipment":["outdoor_bike","indoor_trainer"],"segments":[{"minutes":45,"zone":"Z2"}]}', '{"ftp_percent":[55,70]}', '{"max_pw_hr":7.5}', '{"progress_duration_percent":10}', array['RECOVERY_30'], 'v2.0.0'),
  ('TEMPO_60', 'tempo', 4, array['BASE','BUILD','SPECIALTY']::public.training_phase[], 'tempo', 'durability', 60, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":3,"work_minutes":12}', '{"ftp_percent":[80,87]}', '{"target_completion":90}', '{"progress_work_minutes":3}', array['ENDURANCE_45'], 'v2.0.0'),
  ('SWEET_SPOT_60', 'sweet_spot', 5, array['BASE','BUILD','SPECIALTY']::public.training_phase[], 'threshold', 'durability', 60, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":3,"work_minutes":10}', '{"ftp_percent":[88,94]}', '{"target_completion":90}', '{"progress_work_minutes":2}', array['TEMPO_60','ENDURANCE_45'], 'v2.0.0'),
  ('THRESHOLD_65', 'threshold', 7, array['BUILD','SPECIALTY','PEAK']::public.training_phase[], 'threshold', 'repeatability', 65, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":4,"work_minutes":8}', '{"ftp_percent":[98,105]}', '{"target_completion":90}', '{"progress_work_minutes":2}', array['SWEET_SPOT_60'], 'v2.0.0'),
  ('VO2_MAX_55', 'vo2_max', 8, array['BUILD','SPECIALTY','PEAK']::public.training_phase[], 'vo2_max', 'repeatability', 55, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":5,"work_minutes":4}', '{"ftp_percent":[108,118]}', '{"target_completion":85}', '{"progress_repetitions":1}', array['THRESHOLD_65'], 'v2.0.0'),
  ('ANAEROBIC_50', 'anaerobic', 9, array['SPECIALTY','PEAK']::public.training_phase[], 'anaerobic_capacity', 'repeatability', 50, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":8,"work_seconds":60}', '{"ftp_percent":[130,160]}', '{"target_completion":85}', '{"progress_repetitions":1}', array['VO2_MAX_55'], 'v2.0.0'),
  ('SPRINT_45', 'sprint', 9, array['BUILD','SPECIALTY','PEAK']::public.training_phase[], 'sprint_power', 'neuromuscular_power', 45, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":8,"work_seconds":12}', '{"effort":"maximal_controlled"}', '{"power_fade_max_percent":10}', '{"progress_repetitions":1}', array['CADENCE_45'], 'v2.0.0'),
  ('NEUROMUSCULAR_45', 'neuromuscular', 6, array['BASE','BUILD','SPECIALTY','PEAK','TAPER']::public.training_phase[], 'neuromuscular_power', 'sprint_power', 45, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":6,"work_seconds":8}', '{"effort":"fast_not_fatigued"}', '{"quality_repetitions":6}', '{"progress_repetitions":1}', array['CADENCE_45'], 'v2.0.0'),
  ('CADENCE_45', 'cadence', 3, array['BASE','BUILD','SPECIALTY','PEAK','TAPER','RECOVERY']::public.training_phase[], 'pedalling_efficiency', 'aerobic_endurance', 45, '{"equipment":["outdoor_bike","indoor_trainer"],"cadence_blocks":6}', '{"cadence_rpm":[95,110]}', '{"smooth_blocks":6}', '{"progress_block_minutes":1}', array['ENDURANCE_45'], 'v2.0.0'),
  ('CLIMBING_75', 'climbing', 7, array['BUILD','SPECIALTY','PEAK']::public.training_phase[], 'climbing', 'threshold', 75, '{"equipment":["outdoor_bike","indoor_trainer"],"work_intervals":4,"work_minutes":10}', '{"ftp_percent":[90,100]}', '{"target_completion":90}', '{"progress_work_minutes":2}', array['SWEET_SPOT_60'], 'v2.0.0'),
  ('RACE_SIM_120', 'race_simulation', 10, array['SPECIALTY','PEAK']::public.training_phase[], 'event_specificity', 'durability', 120, '{"equipment":["outdoor_bike"],"terrain":"event_specific"}', '{"variable_pacing":true}', '{"pacing_and_fueling":true}', '{"repeat_only_when_absorbed":true}', array['CLIMBING_75','ENDURANCE_45'], 'v2.0.0')
on conflict (id) do update set
  session_type = excluded.session_type,
  difficulty_level = excluded.difficulty_level,
  intended_phases = excluded.intended_phases,
  primary_adaptation = excluded.primary_adaptation,
  secondary_adaptation = excluded.secondary_adaptation,
  duration_minutes = excluded.duration_minutes,
  interval_structure = excluded.interval_structure,
  intensity_targets = excluded.intensity_targets,
  success_metrics = excluded.success_metrics,
  progression_rules = excluded.progression_rules,
  regression_alternatives = excluded.regression_alternatives,
  library_version = excluded.library_version,
  active = true;

create or replace function public.apply_adaptive_decision(
  target_session_id uuid,
  decision_payload jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  target public.planned_sessions;
  decision_id uuid;
begin
  select * into target from public.planned_sessions where id = target_session_id for update;
  if target.id is null then raise exception 'planned session not found'; end if;
  if (decision_payload->>'athlete_id')::uuid <> target.athlete_id then
    raise exception 'decision athlete does not own planned session';
  end if;
  select id into decision_id from public.adaptive_decisions
  where athlete_id = target.athlete_id
    and decision_key = decision_payload->>'decision_key';
  if decision_id is not null then return decision_id; end if;

  insert into public.adaptive_decisions (
    athlete_id, affected_session_id, original_workout, replacement_workout,
    adaptation_level, decision, reason_codes, evidence, explanation,
    confidence, coaching_model_version, decision_key
  ) values (
    target.athlete_id, target.id, decision_payload->'original_workout',
    decision_payload->'replacement_workout',
    (decision_payload->>'adaptation_level')::smallint,
    decision_payload->>'decision',
    array(select jsonb_array_elements_text(decision_payload->'reason_codes')),
    decision_payload->'evidence', decision_payload->>'explanation',
    (decision_payload->>'confidence')::numeric,
    decision_payload->>'coaching_model_version', decision_payload->>'decision_key'
  ) returning id into decision_id;

  update public.planned_sessions set
    original_workout_id = coalesce(original_workout_id, workout_library_id, current_workout_id),
    current_workout_id = nullif(decision_payload->>'replacement_workout_id', ''),
    workout_library_id = coalesce(nullif(decision_payload->>'replacement_workout_id', ''), workout_library_id),
    adaptation_status = decision_payload->>'decision',
    source_evidence = decision_payload->'evidence',
    algorithm_version = decision_payload->>'coaching_model_version',
    updated_at = now()
  where id = target.id;
  return decision_id;
end;
$$;
revoke all on function public.apply_adaptive_decision(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.apply_adaptive_decision(uuid, jsonb) to service_role;
