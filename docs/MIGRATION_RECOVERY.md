# Server Migration Recovery

Supabase migrations are immutable after production deployment. Never edit,
delete or reorder an applied migration. If deployment fails or a defect is
found, preserve the failed version in migration history and recover with a new,
forward-only migration.

## Before deployment

1. Confirm the production backup is current and note its restore point.
2. Run the complete test suite and the migration recovery contract test.
3. Review locks, data rewrites, constraints, functions, RLS and grants.
4. Create `supabase/migrations/recovery/<migration-name>.md` using the required
   Risk, Rollback, Forward recovery and Verification headings.
5. Prefer additive and repeatable SQL (`if exists`, `if not exists`, or
   `create or replace`) and separate large data backfills from schema changes.

## Failed deployment

Do not run `supabase db reset` against a linked or production project. Capture
the CLI error and migration status first. If PostgreSQL rolled back the
transaction, correct the defect in a new migration and deploy it. If an
external or non-transactional side effect occurred, follow the migration's
recovery note before deploying the compensating migration.

## Production regression

The default response is forward recovery: stop affected workers if necessary,
take a fresh backup, add a migration that restores a compatible contract, test
it against representative data, deploy it, then verify application reads and
writes. A logical rollback is used only when its recovery note proves that no
newer data will be lost and no deployed client depends on the new contract.
Restoring a database backup is the final option and requires reconciling every
write accepted after the restore point.

## Verification record

Record the migration version, deploy time, target project, migration-list
output, verification queries and application smoke-test result without tokens,
credentials, athlete identifiers or health data. Migration recovery notes are
operational instructions, never a place to paste production output.
