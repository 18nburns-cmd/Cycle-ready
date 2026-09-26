# Keep adaptive plan fields consistent

## Risk

This migration widens the planned-duration constraint to permit a zero-minute
rest decision and replaces `apply_adaptive_decision`. An incompatible function
definition could block daily coaching; incorrect field mapping could make the
calendar, Today and provider-delivery queue disagree.

## Rollback

Pause daily coaching and workout delivery before changing the function. A
logical rollback is a new migration restoring the prior function definition
and the prior positive-duration constraint only after confirming that no rest
rows have `planned_duration_minutes = 0`. Restoring the old function also
restores the known display-field inconsistency, so it is not the preferred
response.

## Forward recovery

Create a later migration using `create or replace function` with the corrected
mapping. Keep the widened non-negative duration constraint because zero-minute
rest rows are valid. Re-run the affected athlete/day through `daily-coaching`;
the decision key and locked RPC make that repair idempotent.

## Verification

Verify that the migration appears in `supabase migration list`. In a disposable
or staging athlete, apply an ENDURANCE replacement and a REST replacement, then
confirm workout ID, session type, purpose, duration, planned load and adaptation
status change atomically. Confirm Today and the plan calendar return the same
fields and that the delivery outbox contains no duplicate active operation.
