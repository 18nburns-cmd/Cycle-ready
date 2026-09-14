create or replace function public.retry_workout_delivery(
  p_planned_session_id uuid,
  p_provider text default 'intervals-icu'
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  delivery public.workout_deliveries;
  retried_id uuid;
begin
  select wd.* into delivery
  from public.workout_deliveries wd
  join public.planned_sessions ps on ps.id = wd.planned_session_id
  where wd.planned_session_id = p_planned_session_id
    and wd.provider = p_provider
    and public.owns_athlete(wd.athlete_id)
    and ps.scheduled_date >= current_date
    and ps.completion_status = 'planned'
    and wd.delivery_status = 'failed'
  for update of wd;

  if not found then return false; end if;

  select id into retried_id
  from public.workout_delivery_outbox
  where delivery_id = delivery.id and status = 'failed'
  order by created_at desc
  limit 1
  for update;

  if retried_id is null then return false; end if;

  update public.workout_delivery_outbox
  set status = 'pending', next_attempt_at = now(), last_error = null,
      completed_at = null
  where id = retried_id;
  update public.workout_deliveries
  set delivery_status = 'pending', failure_message = null
  where id = delivery.id;
  return true;
end;
$$;

create or replace function public.retry_future_workout_deliveries(
  p_provider text default 'intervals-icu'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
  retry_count integer := 0;
begin
  for item in
    select wd.planned_session_id
    from public.workout_deliveries wd
    join public.planned_sessions ps on ps.id = wd.planned_session_id
    where wd.provider = p_provider
      and public.owns_athlete(wd.athlete_id)
      and ps.scheduled_date >= current_date
      and ps.completion_status = 'planned'
      and wd.delivery_status = 'failed'
  loop
    if public.retry_workout_delivery(item.planned_session_id, p_provider) then
      retry_count := retry_count + 1;
    end if;
  end loop;
  return retry_count;
end;
$$;

revoke all on function public.retry_workout_delivery(uuid, text) from public;
revoke all on function public.retry_future_workout_deliveries(text) from public;
grant execute on function public.retry_workout_delivery(uuid, text) to authenticated;
grant execute on function public.retry_future_workout_deliveries(text) to authenticated;
