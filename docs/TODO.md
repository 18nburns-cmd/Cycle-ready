# CycleReady delivery tasks

This list was restored on 24 August 2026 by auditing the current codebase
against `PRODUCT_SPEC.md` and `ARCHITECTURE.md`. Tasks are ordered so later
coaching work can rely on stable athlete data and domain boundaries.

## Current priority

- [x] Add a dedicated responsive Flutter web entry point and dashboard shell
      that remains buildable despite Android-only health and device plugins.

- [x] Add authenticated cloud storage so Android and web can share the same
      athlete, activity, wellness, nutrition and coaching data.

- [x] Validate the first authenticated phone upload without exposing one
      athlete's cloud snapshot to another account.

- [x] Deploy the configured release dashboard to a stable HTTPS address and
      validate its first authenticated web read. GitHub Pages release 9 was
      verified with the athlete's account and synced headline metrics on
      25 August 2026.

- [x] Replace the web placeholders with responsive Today, Performance,
      Calendar, Wellness and Nutrition views backed by the authenticated
      athlete snapshot, including ride metrics, FTP, power-to-weight, recovery,
      check-ins, body trends, planned sessions and daily intake progress.

- [ ] Add chunked cloud storage for second-by-second activity samples so web
      ride charts can load detailed power, heart-rate and cadence traces.

- [x] Remove duplicate connected-service sync status from Today while keeping
      full status and manual retry controls in Connect.

- [x] Cache successful preferred-time weather forecasts for offline display,
      expose updated/stale status on Today and prevent stale forecasts from
      silently changing adaptive outdoor workouts.

- [x] Add real SQLite migration-fixture tests for pre-profile-expansion schema
      17 and pre-weather-profile schema 19, proving current upgrades preserve
      athlete identity, physiology, rides and existing location data.

- [x] Harden automatic connected-service sync with persisted exponential
      retry, restart-safe next-attempt scheduling and visible Today status with
      a manual retry that does not discard existing offline data.

- [x] Compare matched structured-workout steps with completed power samples;
      report interval completion, target accuracy and late-session fade in the
      persisted post-ride coaching report only when sample coverage is adequate.

- [x] Show the preferred-time outdoor forecast on Today and let the athlete
      choose a cautious, balanced or resilient riding-safety profile that the
      adaptive planner uses when deciding whether to move a ride indoors.

- [x] Add a coaching-grade rolling 12-week seasonal review that compares the
      current block with the preceding block across load, consistency,
      recovery and body-weight trends, with confidence and next priorities.

- [x] Match imported rides to planned workouts using date proximity, session
      name, duration and load; use the match for compliance learning and
      persisted post-ride coaching reports.

- [x] Add weather-aware outdoor planning through a replaceable forecast
      service, athlete training location and deterministic riding-safety rules.

- [x] Move learned workout-response persistence and coaching-decision
      processing behind a coaching repository; expose domain snapshots to the
      workout explanation and daily coaching context.

- [x] Remove direct database reads from the training-plan presentation layer;
      obtain athlete targets and training preferences through feature providers.

- [x] Move body-composition persistence behind a domain repository and keep
      manual, Bluetooth, CSV and Health Connect writes synchronized with the
      athlete profile as the single source of current weight.

- [x] Move goal-event persistence to a coaching domain entity and repository;
      use it from the goal screen, adaptive planner and daily coaching context.

- [x] Move planned-session and training-preference persistence behind a
      coaching repository so calendar providers/controllers do not construct
      Drift companions or query those tables directly.

- [x] Expand the athlete profile with bike/equipment, power-meter and trainer
      availability, preferred ride time, nutrition preferences and injury notes;
      prevent indoor-only planning when no trainer is available.

- [x] Expand the athlete profile as the single source of truth: persist and edit
      identity, core physiology and experience alongside existing FTP/load data.
- [x] Move athlete profile persistence behind a feature repository and controller
      so presentation code no longer accesses Drift directly.
- [x] Build a structured daily coaching context that combines athlete profile,
      readiness, recent rides, goal phase, availability and learned response.
- [x] Refresh future adaptive workout targets automatically when FTP changes,
      without modifying completed or manually planned sessions.
- [x] Add confidence and evidence fields to every generated daily workout
      recommendation and expose them consistently in the UI.
- [x] Add after-ride comparison against the planned workout with an explicit
      tomorrow recommendation persisted in coaching history.
- [x] Refresh `README.md` and `docs/ROADMAP.md` to describe the current product
      rather than the original foundation increment.

## Quality baseline

- [x] `flutter analyze` completes without warnings.
- [x] Full test suite passes (238 tests on 25 August 2026).
