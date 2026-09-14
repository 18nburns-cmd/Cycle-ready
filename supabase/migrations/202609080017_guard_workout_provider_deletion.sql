alter table public.workout_deliveries
  add column managed_by text not null default 'cycleready'
  check (managed_by = 'cycleready');

create or replace function public.guard_workout_delivery_delete_command()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare delivery public.workout_deliveries;
declare completion text;
begin
  if new.operation <> 'delete' then return new; end if;
  select * into delivery from public.workout_deliveries where id = new.delivery_id;
  if not found or delivery.managed_by <> 'cycleready'
     or delivery.external_workout_id is null then
    raise exception 'Only an acknowledged CycleReady workout can be deleted';
  end if;
  if delivery.planned_session_id is not null then
    select completion_status into completion from public.planned_sessions
    where id = delivery.planned_session_id;
    if completion <> 'planned' then
      raise exception 'Completed workouts cannot be deleted from a provider';
    end if;
  end if;
  return new;
end;
$$;

create trigger workout_delivery_outbox_guard_delete
  before insert or update of operation on public.workout_delivery_outbox
  for each row execute function public.guard_workout_delivery_delete_command();
