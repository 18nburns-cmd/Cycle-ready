alter table public.planned_sessions
  drop constraint if exists planned_sessions_planned_duration_minutes_check;

alter table public.planned_sessions
  add constraint planned_sessions_planned_duration_minutes_check
  check (planned_duration_minutes >= 0);

create or replace function public.apply_adaptive_decision(
  target_session_id uuid,
  decision_payload jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  target public.planned_sessions;
  decision_id uuid;
  replacement jsonb := decision_payload->'replacement_workout';
  rest_selected boolean := upper(coalesce(decision_payload->>'decision', '')) = 'REST';
begin
  select * into target from public.planned_sessions
  where id = target_session_id for update;
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
    replacement,
    (decision_payload->>'adaptation_level')::smallint,
    decision_payload->>'decision',
    array(select jsonb_array_elements_text(decision_payload->'reason_codes')),
    decision_payload->'evidence', decision_payload->>'explanation',
    (decision_payload->>'confidence')::numeric,
    decision_payload->>'coaching_model_version', decision_payload->>'decision_key'
  ) returning id into decision_id;

  update public.planned_sessions set
    original_workout_id = coalesce(
      original_workout_id,
      workout_library_id,
      current_workout_id
    ),
    current_workout_id = case when rest_selected then null
      else nullif(decision_payload->>'replacement_workout_id', '') end,
    workout_library_id = case when rest_selected then null
      else coalesce(
        nullif(decision_payload->>'replacement_workout_id', ''),
        workout_library_id
      ) end,
    session_type = case when rest_selected then 'rest'
      else coalesce(replacement->>'session_type', replacement->>'family', session_type) end,
    primary_adaptation = case when rest_selected then 'recovery'
      else coalesce(replacement->>'primary_adaptation', primary_adaptation) end,
    secondary_adaptation = case when rest_selected then null
      else coalesce(replacement->>'secondary_adaptation', secondary_adaptation) end,
    purpose = case when rest_selected then 'Rest day'
      else coalesce(nullif(replacement->>'title', ''), purpose) end,
    planned_duration_minutes = case when rest_selected then 0
      else coalesce((replacement->>'duration_minutes')::integer, planned_duration_minutes) end,
    planned_load = case when rest_selected then 0
      else coalesce((replacement->>'target_load')::numeric, planned_load) end,
    adaptation_status = decision_payload->>'decision',
    source_evidence = decision_payload->'evidence',
    algorithm_version = decision_payload->>'coaching_model_version',
    updated_at = now()
  where id = target.id;
  return decision_id;
end;
$$;

revoke all on function public.apply_adaptive_decision(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_adaptive_decision(uuid, jsonb)
  to service_role;
