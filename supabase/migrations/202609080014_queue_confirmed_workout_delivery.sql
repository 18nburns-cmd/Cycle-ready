create or replace function public.queue_planned_workout_delivery()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  workout_payload jsonb;
  payload_hash text;
  delivery public.workout_deliveries;
  next_version integer;
  operation_name text;
begin
  if new.completion_status <> 'planned'
     or new.session_type = 'rest'
     or new.planned_duration_minutes <= 0 then
    return new;
  end if;

  workout_payload := jsonb_build_object(
    'planned_session_id', new.id,
    'scheduled_date', new.scheduled_date,
    'workout_id', coalesce(new.current_workout_id, new.workout_library_id),
    'session_type', new.session_type,
    'purpose', new.purpose,
    'primary_adaptation', new.primary_adaptation,
    'duration_minutes', new.planned_duration_minutes,
    'target_load', coalesce(new.planned_load, 0)
  );
  payload_hash := encode(digest(workout_payload::text, 'sha256'), 'hex');

  select * into delivery from public.workout_deliveries
  where planned_session_id = new.id and provider = 'intervals-icu'
  for update;

  if found and delivery.desired_content_hash = payload_hash then
    return new;
  end if;

  next_version := coalesce(delivery.desired_version, 0) + 1;
  operation_name := case
    when delivery.external_workout_id is null then 'create'
    else 'update'
  end;

  insert into public.workout_deliveries (
    athlete_id, planned_session_id, provider, desired_content_hash,
    desired_version, delivery_status
  ) values (
    new.athlete_id, new.id, 'intervals-icu', payload_hash,
    next_version, 'pending'
  )
  on conflict (planned_session_id, provider) do update set
    desired_content_hash = excluded.desired_content_hash,
    desired_version = excluded.desired_version,
    delivery_status = 'pending',
    failure_message = null
  returning * into delivery;

  insert into public.workout_delivery_outbox (
    athlete_id, delivery_id, provider, operation, idempotency_key,
    content_hash, payload
  ) values (
    new.athlete_id, delivery.id, delivery.provider, operation_name,
    new.id::text || ':' || delivery.provider || ':' || operation_name || ':' || next_version,
    payload_hash, workout_payload
  ) on conflict (athlete_id, idempotency_key) do nothing;

  return new;
end;
$$;

create trigger planned_sessions_queue_workout_delivery
  after insert or update of scheduled_date, workout_library_id,
    current_workout_id, session_type, purpose, primary_adaptation,
    planned_duration_minutes, planned_load, completion_status
  on public.planned_sessions
  for each row execute function public.queue_planned_workout_delivery();

-- Existing future planned sessions enter the same idempotent path once.
update public.planned_sessions
set planned_load = planned_load
where completion_status = 'planned'
  and scheduled_date >= current_date
  and session_type <> 'rest';
