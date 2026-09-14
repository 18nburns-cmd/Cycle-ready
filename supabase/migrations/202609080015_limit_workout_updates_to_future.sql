drop trigger if exists planned_sessions_queue_workout_delivery
  on public.planned_sessions;

create trigger planned_sessions_queue_workout_delivery
  after insert or update of scheduled_date, workout_library_id,
    current_workout_id, session_type, purpose, primary_adaptation,
    planned_duration_minutes, planned_load, completion_status
  on public.planned_sessions
  for each row
  when (new.scheduled_date >= current_date)
  execute function public.queue_planned_workout_delivery();
