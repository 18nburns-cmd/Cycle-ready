alter table public.workout_deliveries
  drop constraint workout_deliveries_planned_session_id_fkey;
alter table public.workout_deliveries
  alter column planned_session_id drop not null;
alter table public.workout_deliveries
  add constraint workout_deliveries_planned_session_id_fkey
  foreign key (planned_session_id) references public.planned_sessions(id)
  on delete set null;

create or replace function public.queue_deleted_workout_delivery()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare delivery public.workout_deliveries;
declare delete_version integer;
begin
  if old.scheduled_date < current_date or old.completion_status <> 'planned' then
    return old;
  end if;
  select * into delivery from public.workout_deliveries
  where planned_session_id = old.id and provider = 'intervals-icu'
  for update;
  if not found then return old; end if;

  if delivery.external_workout_id is null then
    update public.workout_delivery_outbox
    set status = 'completed', completed_at = now()
    where delivery_id = delivery.id and status in ('pending', 'failed');
    update public.workout_deliveries set delivery_status = 'deleted'
    where id = delivery.id;
    return old;
  end if;

  delete_version := delivery.desired_version + 1;
  insert into public.workout_delivery_outbox (
    athlete_id, delivery_id, provider, operation, idempotency_key,
    content_hash, payload
  ) values (
    old.athlete_id, delivery.id, delivery.provider, 'delete',
    old.id::text || ':' || delivery.provider || ':delete:' || delete_version,
    delivery.desired_content_hash,
    jsonb_build_object(
      'planned_session_id', old.id,
      'external_workout_id', delivery.external_workout_id,
      'scheduled_date', old.scheduled_date
    )
  ) on conflict (athlete_id, idempotency_key) do nothing;
  update public.workout_deliveries set
    delivery_status = 'pending', desired_version = delete_version,
    failure_message = null
  where id = delivery.id;
  return old;
end;
$$;

create trigger planned_sessions_queue_workout_deletion
  before delete on public.planned_sessions
  for each row execute function public.queue_deleted_workout_delivery();
