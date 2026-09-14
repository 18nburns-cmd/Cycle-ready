-- Preserve every source row and expose one deterministic daily record to the
-- coaching engine. Manual data wins, followed by Health Connect and provider
-- imports; newest data breaks ties. security_invoker keeps underlying RLS.
create view public.resolved_daily_wellness
with (security_invoker = true)
as
select id, athlete_id, recorded_date, hrv_ms, resting_hr, sleep_minutes,
  sleep_quality, fatigue, soreness, stress, motivation, weight_kg,
  illness_flag, injury_or_pain_flag, source, imported_at, updated_at
from (
  select wellness.*,
    row_number() over (
      partition by athlete_id, recorded_date
      order by case source
        when 'manual' then 1
        when 'health_connect' then 2
        when 'intervals_icu' then 3
        else 10
      end, updated_at desc, imported_at desc
    ) as source_rank
  from public.wellness
) ranked
where source_rank = 1;

grant select on public.resolved_daily_wellness to authenticated;

