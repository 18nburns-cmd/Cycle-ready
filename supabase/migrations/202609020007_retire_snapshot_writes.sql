-- Production relational parity was validated on 2 September 2026. Keep the
-- final snapshot as a read-only migration archive, but prevent every client
-- from continuing the compatibility transport.
revoke insert, update, delete on public.athlete_snapshots from authenticated;

drop policy if exists "Athletes create their own snapshot"
  on public.athlete_snapshots;
drop policy if exists "Athletes update their own snapshot"
  on public.athlete_snapshots;
drop policy if exists "Athletes delete their own snapshot"
  on public.athlete_snapshots;
