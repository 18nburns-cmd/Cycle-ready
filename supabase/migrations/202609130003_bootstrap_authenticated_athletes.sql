create or replace function public.bootstrap_authenticated_athlete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  athlete_name text;
begin
  athlete_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'CycleReady athlete'
  );
  insert into public.athletes (user_id, name)
  values (new.id, athlete_name)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists auth_user_bootstrap_athlete on auth.users;
create trigger auth_user_bootstrap_athlete
after insert on auth.users
for each row execute function public.bootstrap_authenticated_athlete();

insert into public.athletes (user_id, name)
select u.id,
       coalesce(
         nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
         nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
         'CycleReady athlete'
       )
from auth.users u
where not exists (
  select 1 from public.athletes a where a.user_id = u.id
)
on conflict (user_id) do nothing;
