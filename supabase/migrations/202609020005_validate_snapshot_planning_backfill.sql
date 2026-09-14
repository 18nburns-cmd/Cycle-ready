-- Record parity only after real planning inputs reached canonical relations.
do $$
begin
  if not exists (select 1 from public.goals) then
    raise exception 'Planning parity blocked: relational goal missing.';
  end if;
  if not exists (select 1 from public.planned_sessions) then
    raise exception 'Planning parity blocked: relational planned session missing.';
  end if;
end
$$;
