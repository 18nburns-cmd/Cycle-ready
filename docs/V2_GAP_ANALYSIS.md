# CycleReady v2 Implementation Gap Analysis

Assessment date: 31 August 2026

The Adaptive Cycling Coach Master Implementation Specification v2.0 is the
governing product contract. `PRODUCT_SPEC.md`, `ARCHITECTURE.md`, and
`TODO.md` translate that contract into product behavior, technical boundaries,
and dependency-ordered work. Repeated `IMPLEMENT` clauses in the master
specification are enforced as common invariants across every processing
component.

## Already achieved

- Clean, feature-first Flutter architecture with Riverpod, repositories, Drift,
  Android and a separately composed responsive web client.
- Athlete profile/state, readiness, CTL/ATL/TSB, workout generation, ride
  analysis, event periodisation, adaptive policy, session-outcome policy,
  learning, weather safety, nutrition, body composition, and detailed tests.
- Authenticated Supabase project with athlete-isolated RLS, compatibility
  snapshot transport, chunked activity samples, and a relational coaching core.
- Deployed, secret-backed Intervals.icu activity and wellness import. Stable
  provider identities make repeated imports idempotent; a full import and
  repeat run were verified against production data.
- Source-prioritized daily wellness resolution and the explicit maximum-two
  consecutive recovery-session rule with its six evidence-based exceptions.

## Gaps and dependency order

1. **Cloud contract completion — deployed.** Added
   event demands, capability history, phases, weeks, materialized resolved
   wellness, coaching snapshots, processing runs, sync runs, feedback, and
   notifications without deleting the live compatibility data.
2. **Derived metrics — deployed.** Calculate versioned CTL, ATL, TSB, load trend, power
   evidence, recovery baselines, and capability evidence on the server with
   source references and idempotent processing-run records.
3. **Readiness and athlete state — deployed.** Resolve confidence-aware daily state from
   source facts; symptoms override wearable scores and missing evidence lowers
   confidence.
4. **Goal-directed planning — deployed.** Persist event-demand profiles, capability gaps,
   phases, blocks, weeks, and stable workout-library prescriptions.
5. **Post-session learning — deployed.** Run family-specific stimulus analysis after
   import, update recovery cost after 12–48 hours, validate Pw:Hr and durability,
   and record achieved-and-absorbed evidence.
6. **Authoritative daily coach — deployed.** Apply safety before ranking, use the specified
   suitability weights and KEEP tie behavior, enforce swap ladders and
   minimum-effective change, then append the decision and revision atomically.
7. **Shared clients — relational reads and offline queue implemented.** Move Flutter and web reads from compatibility snapshots
   to the same relational decision object, add an offline mutation queue with
   deterministic conflicts, validate parity, then retire snapshot writes.
8. **Operational completion.** Intervals OAuth, authenticated webhooks, hourly
   server synchronization, run-ledger observability and stale-sync alerts are
   deployed. Notification delivery, remaining provider adapters, security
   tests and final web/Android acceptance validation remain.

## Cross-cutting acceptance invariants

Every derived output is versioned and attributable; every automatic decision
has reason codes and confidence; original prescriptions are retained; missing
data is never invented; safety precedes candidate ranking; block purpose remains
available; candidates declare adaptations and satisfy duration, equipment,
taper, illness, and pain constraints; KEEP wins near ties; progression uses
comparable absorbed evidence and recovery cost; session analysis is
family-specific; Pw:Hr and durability require valid evidence; provider
reprocessing is idempotent; and mobile and web consume one authoritative object.

## Current validation gate

All 303 Flutter tests pass, `flutter analyze` is clean, and the release web
build succeeds. Android release compilation and R8 shrinking succeed after
adding rules for optional ML Kit recognizers. The corrected 127,425,650-byte
APK is preserved as `CycleReady-v2-release.apk` with SHA-256
`BA434AF481FEEB85FDE69F0A5BD252F3784D8C569207AAFC58C3225DCB032AE3`.
It was installed on the athlete's Samsung SM-S948B and cold-started without a
Flutter, Android, notification-resource, or Health Connect permission error.
The expanded Health Connect permission contract was then approved by the
athlete and a manual sync completed with a clean device log on 2 September
2026.
Snapshot retirement remains intentionally blocked until one authenticated
production pipeline run confirms relational row parity.
## Production pipeline validation — 2 September 2026

An authenticated manual invocation of `intervals-sync` returned HTTP 200 and
imported 7 activities plus 15 wellness observations. Production row inspection
confirmed derived training metrics, physiological baselines, athlete
capabilities, daily readiness, session analysis and the coaching-state snapshot.

The first compatibility snapshot held no event goal or planned session, so goal
periodisation and adaptive decision processing correctly emitted no rows. A
subsequent production upload migrated 1 goal and 17 sessions. After correcting
local-calendar epoch timestamps for British Summer Time, the pipeline produced
the event-demand profile, 5 phases, 5 blocks, weekly plans and an append-only
adaptive decision. Snapshot writes are now disabled; the final row is retained
read-only as a migration archive.
