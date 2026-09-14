-- Preserve the authenticated owner of the compatibility snapshot while the
-- normalized profile is progressively populated by client/server sync.
insert into public.athletes (user_id, name)
select user_id, 'CycleReady athlete'
from public.athlete_snapshots
on conflict (user_id) do nothing;

