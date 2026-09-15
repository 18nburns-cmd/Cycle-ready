# CycleReady Engineering Backlog — Coaching Loop v3

This backlog contains only work that remains after the completed v2 foundation.
It is ordered by dependency and value for CycleReady's single-athlete use case.
The governing product and architecture contracts remain `PRODUCT_SPEC.md` and
`ARCHITECTURE.md`.

## Working rules

- Complete the first unchecked task before starting another task.
- Keep each change inside the UI -> controller -> domain -> repository -> data
  source dependency direction.
- Add or update tests with every behavior change; never defer a broken suite.
- Update product and architecture documentation in the same task when their
  contracts change.
- Never expose provider credentials or commit secrets.
- Do not commit unless the user explicitly requests it.

## EPIC 1 — Canonical Workout Catalogue

Goal: replace parallel workout definitions with one versioned domain catalogue
used by planning, ad-hoc selection, analysis and delivery.

- [x] Define a provider-neutral `WorkoutFamily`, `WorkoutVariant` and
      `WorkoutProgression` domain contract with stable identifiers.
- [x] Add explicit cadence, terrain, equipment, adaptation, recovery-time and
      success-criteria fields to the canonical workout contract.
- [x] Model warm-up, work, recovery and cool-down steps without parsing display
      titles or prescription strings.
- [x] Create a catalogue repository interface supporting family, phase,
      duration and equipment queries.
- [x] Implement the local catalogue repository by adapting the existing
      generated workout library without duplicating workout definitions.
- [x] Add versioned Supabase catalogue tables and athlete-safe read policies.
- [x] Seed the server catalogue deterministically from canonical workout IDs.
- [x] Add progression and regression links for every supported workout family.
- [x] Add duration variants for short, standard and extended training windows.
- [x] Add domain validation for step duration, power range, cadence, recovery
      and total workout duration.
- [x] Add unit tests proving stable IDs, complete family coverage and valid
      progression graphs.
- [x] Add migration tests proving catalogue deployment is repeatable and does
      not alter athlete-owned plan history.
- [x] Update `PRODUCT_SPEC.md` and `ARCHITECTURE.md` with the canonical catalogue
      ownership and versioning rules.

## EPIC 2 — Contextual Workout Selection

Goal: make every workout choice reflect the athlete, plan purpose and available
time rather than rotating through generic choices.

- [x] Define an immutable workout-selection context containing athlete state,
      goal, phase, weekly intent, recent load, recovery, availability,
      equipment, weather and learned response.
- [x] Move unplanned-day choice construction behind a domain selection service.
- [x] Replace date-based best-fit rotation with evidence-based candidate
      scoring from the canonical selection context.
- [x] Include the current block adaptation target in candidate scoring.
- [x] Include power-duration capability gaps in candidate scoring.
- [x] Include family-specific historical success and recovery cost in scoring.
- [x] Apply planned hard-session spacing across both completed and future work.
- [x] Apply available-time and indoor/outdoor constraints before ranking.
- [x] Return explicit score components, confidence and rejection reasons for
      every evaluated candidate.
- [x] Add a workout-browser controller with family and duration filters while
      keeping unsafe candidates unavailable.
- [x] Update the empty-day picker to group variants by adaptation and show why
      the recommended session outranks alternatives.
- [x] Add unit tests for selection ranking, safety exclusion, missing evidence
      and deterministic tie-breaking.
- [x] Add widget tests for browsing, filtering and selecting a safe workout.
- [x] Update product and architecture documentation for contextual selection.

## EPIC 3 — Autonomous Daily Coaching Pipeline

## User-requested delivery â€” Searchable Food and Drink Catalogue

- [x] Define immutable food/drink and serving-scaling domain models.
- [x] Add a repository boundary for text and barcode catalogue lookup.
- [x] Add on-device EAN/UPC barcode scanning and automatic product lookup.
- [x] Route found products through portion scaling, logging and favourites.
- [x] Explain unknown barcodes and preserve name/label entry fallbacks.
- [x] Bundle common foods, drinks and cycling fuel for offline use.
- [x] Integrate read-only branded-product search with graceful offline fallback.
- [x] Add searchable browsing with automatic nutrition values.
- [x] Scale nutrition to the selected portion and support existing favourites.
- [x] Add unit and widget coverage and update product/architecture documentation.

Goal: produce the day's authoritative recommendation on the server even when
the phone is closed.

- [x] Define a versioned server-side daily coaching input and output contract.
- [x] Add an idempotent database function that assembles one athlete-day
      context from authoritative relational records.
- [x] Implement a server-side orchestration function that runs readiness,
      candidate selection, safety checks and adaptive decision processing.
- [x] Persist the exact evidence snapshot used by each daily recommendation.
- [x] Add a per-athlete, per-day idempotency key preventing duplicate decisions.
- [x] Schedule morning coaching execution in the athlete's configured timezone.
- [x] Re-run the pipeline only when material same-day evidence changes.
- [x] Add failure isolation and retry state without blocking data imports.
- [x] Expose last-run, next-run, model-version and failure status through a
      repository contract.
- [x] Update Android Today to consume the authoritative daily recommendation
      with an explicit offline fallback state.
- [x] Update web Today to consume the same recommendation contract.
- [x] Add contract tests comparing server and Dart safety outcomes for shared
      golden scenarios.
- [x] Add Edge Function integration tests for idempotency, timezone boundaries
      and retry behavior.
- [x] Document pipeline ownership, scheduling and fallback behavior.

## User-requested delivery — Ride Review and Recovery Feedback

- [x] Define conservative near-duplicate ride matching with explainable scores.
- [x] Scan stored activities and expose possible duplicate pairs through a repository.
- [x] Flag possible duplicates for athlete review without deleting either ride automatically.
- [x] Add regression coverage proving completed-ride deletion recalculates recovery and preserves tombstones.
- [x] Prompt for the short post-ride quiz after a newly imported recent ride.
- [x] Feed post-ride effort, leg fatigue and discomfort into recovery-time estimation.
- [x] Add unit and widget coverage and document duplicate-review and feedback behavior.

## User-requested repair — Authoritative Today Coaching

- [x] Trace Flutter configuration, authentication, recommendation read and fallback activation.
- [x] Invoke the production coaching endpoint when today's stored recommendation is absent.
- [x] Authenticate app requests and enforce athlete ownership in the Edge Function.
- [x] Parse the direct Edge response through the same Flutter recommendation contract.
- [x] Log endpoint, identity, status, timeout, response and parsing failures.
- [x] Verify the deployed endpoint is active, reachable and rejects unauthenticated requests.
- [x] Document that FCM is notification transport rather than coaching authority.
- [x] Align the adaptive-decision database constraint with all seven
      intent-preserving fallback levels and validate production recovery.

## User-requested refinement — Coaching and Ride Screen Clarity

- [x] Remove the prominent possible-duplicate warning from the Rides dashboard.
- [x] Hide the redundant authoritative-sync success card while preserving checking and fallback warnings.
- [x] Prevent a small rebuilding seven-day load from flattening a ready athlete's future plan into recovery rides.
- [x] Add regression tests and update product and architecture documentation.
- [x] Bound detailed ride-sample uploads to one chunk per HTTP request after a repeatable Android TLS failure.
- [x] Encode the athlete's Monday easy, Wednesday/Saturday quality and Sunday long-ride microcycle with safety overrides.

## User-requested delivery — Private Multi-User Accounts

Goal: allow the same private CycleReady build to serve separate people while
keeping every athlete's health, training and integration data isolated.

- [x] Add registration, login, logout and end-to-end password recovery.
- [x] Bootstrap exactly one athlete record for every authenticated user.
- [x] Replace global single-athlete cloud lookups with an authenticated owner resolver.
- [x] Erase local health, training and provider data securely on logout.
- [x] Prevent a new account from inheriting another account's pending local mutations.
- [x] Scope events, plans, readiness, activities, nutrition and coaching history to the resolved athlete.
- [x] Verify Intervals.icu OAuth credentials and workout outbox ownership per athlete.
- [x] Register notifications and background coaching independently per athlete and timezone.
- [x] Add authenticated cloud-account deletion with provider revocation and local erasure.
- [x] Add multi-user RLS, cross-account denial and logout-cache integration tests.
- [x] Add a signed private APK release channel with version checking and documented updates.
- [ ] Update operating and privacy documentation and validate two physical-phone accounts.

## User-requested delivery — Adaptation-First Strategic Planning

Goal: select the physiological adaptation from event demands, capability gaps,
phase and block intent before selecting or adapting a structured workout.

- [x] Define immutable event-demand, athlete-capability, capability-gap,
      dynamic-phase and strategic training-block domain contracts.
- [x] Add a configurable event-demand model using event type, distance,
      expected duration, elevation and terrain.
- [x] Build a phase-aware weighted workout-family eligibility pool driven by
      primary, secondary and maintenance adaptations.
- [x] Persist the expanded capability dimensions, Foundation phase, block
      duration bounds, progression status and completion criteria.
- [x] Replace fixed server phase allocation with demand-and-gap-aware dynamic
      phase and block selection.
- [x] Make weekly plans select primary, secondary and maintenance adaptation
      objectives before assigning workouts.
- [x] Restrict authoritative server candidate ranking to the eligible family
      pool and log every exclusion and score component.
- [x] Implement the intent-preserving adaptation hierarchy from same-workout
      dose reduction through rest.
- [ ] Require achieved, absorbed and repeated comparable evidence before any
      upward workout progression.
- [ ] Recalculate missed-session microcycles without shifting training debt or
      creating unsafe hard-session density.
- [ ] Add block completion decisions for continue, progress, extend, end,
      deload and rebuild.
- [ ] Persist strategic-decision evidence, reason codes, confidence and model
      version for every selected workout.
- [x] Align Flutter's offline fallback with the shared strategic contract while
      retaining the server as coaching authority.
- [ ] Add automated scenarios A–L from the planning-engine specification.
- [ ] Add parity tests for server and Dart phase, eligibility and safety
      outcomes.
- [ ] Document operational logging and the full adaptation-first decision
      trace.

## User-requested delivery — Multi-Event Planning and Plan Convergence

- [x] Replace the single local event assumption with a stable multi-event
      repository while preserving the existing event.
- [x] Add event-calendar create, edit and individually confirmed delete actions.
- [x] Select the primary planning event by A/B/C priority and date while
      retaining intervening events in generated plans.
- [x] Synchronize multiple events idempotently to authoritative Supabase goals.
- [x] Automatically synchronize every accepted adaptive-plan rebuild.
- [x] Preserve server planned-session identity so changed workouts enqueue
      idempotent Intervals.icu updates rather than duplicate creates.
- [x] Add repository, migration and delivery-regression tests.
- [x] Update product and architecture documentation.

## EPIC 4 — Reliable Workout Delivery and Reconciliation

Goal: ensure the workout shown in CycleReady is the workout available to ride,
and make any delivery failure visible and recoverable.

- [x] Add a delivery-state domain model covering pending, delivered, updated,
      deleted, failed and externally diverged states.
- [x] Persist provider workout IDs, content hashes, delivery attempts and last
      acknowledged versions for each planned session.
- [x] Add an outbox repository for idempotent workout create, update and delete
      operations.
- [x] Queue delivery automatically when an adaptive or athlete-selected workout
      is confirmed.
- [x] Queue provider updates whenever a future delivered workout changes.
- [x] Queue provider deletion when a future CycleReady workout is removed.
- [x] Prevent completed or non-CycleReady provider entries from being deleted.
- [x] Reconcile the CycleReady calendar against Intervals.icu using stable IDs
      and content hashes.
- [x] Surface stale, failed and externally modified workouts in the calendar.
- [x] Add a per-workout retry action and a safe bulk “sync future workouts”
      action.
- [x] Deploy an idempotent scheduled delivery worker and converge phone-created plans before delivery.
- [x] Unify phone and server Intervals.icu external IDs and repair legacy duplicate future workouts idempotently.
- [x] Make OAuth delivery single-authority and reconcile legacy API-key and replaced-plan duplicates by provider event ID.
- [x] Prevent stale phone-side reconciliation from overriding an acknowledged server delivery.
- [ ] Add provider-neutral FIT and ZWO file exporters from structured steps.
- [ ] Add Android share/export actions for manual Garmin, MyWhoosh or trainer
      import where direct APIs are unavailable.
- [ ] Add unit tests for outbox idempotency and reconciliation decisions.
- [ ] Add mocked-provider integration tests for create/update/delete ordering
      and partial failure recovery.
- [ ] Add widget tests for delivery state, retry and manual export flows.
- [ ] Validate one production update and deletion round trip through
      Intervals.icu without affecting completed workouts.
- [ ] Document supported delivery routes and the Garmin/MyWhoosh limitations.

## EPIC 5 — Plan Editing and Change Transparency

Goal: let the athlete safely adjust real-life scheduling while preserving the
coach's intent and making adaptations understandable.

- [ ] Define domain commands for move, swap, shorten, skip and restore-plan
      operations.
- [ ] Add safety validation for moving workouts across hard-session and recovery
      constraints.
- [ ] Preserve the original prescription and reason for every athlete-initiated
      plan change.
- [ ] Implement drag-or-select rescheduling in the Android calendar.
- [ ] Add “swap workout” using only safe same-purpose catalogue candidates.
- [ ] Add “less time available” variants that preserve the primary adaptation.
- [ ] Add an undo window for future plan edits and deletions.
- [ ] Show a concise athlete-facing explanation of what changed and why.
- [ ] Synchronize accepted edits through the delivery outbox.
- [ ] Add domain tests for each edit command and constraint violation.
- [ ] Add widget tests for move, swap, shorten, skip and undo interactions.
- [ ] Document athlete overrides and immutable coaching-history behavior.

## EPIC 6 — Closed-Loop Session Learning

Goal: learn which prescriptions work for this athlete without overreacting to
single sessions or confusing correlation with evidence.

- [ ] Define comparable-session cohorts by workout family, structure, phase and
      environmental context.
- [ ] Persist prescribed dose, achieved dose and delayed recovery response under
      one attributable session-outcome contract.
- [ ] Add data-quality gates for power, heart-rate, subjective and recovery
      evidence before learning updates.
- [ ] Estimate family-specific completion, stimulus and recovery-cost baselines.
- [ ] Learn separate duration and intensity tolerances for each workout family.
- [ ] Learn heat, poor-sleep and low-carbohydrate response modifiers only after
      sufficient repeated evidence.
- [ ] Add confidence decay for stale evidence and confidence growth for repeated
      comparable outcomes.
- [ ] Constrain every learned dose adjustment to a documented safe step size.
- [ ] Feed learned family response into contextual workout ranking.
- [ ] Show the athlete which repeated outcomes caused a progression, hold or
      reduction.
- [ ] Add golden tests proving one anomalous ride cannot materially change the
      model.
- [ ] Add longitudinal tests for progression, regression, stale evidence and
      conflicting signals.
- [ ] Add repository tests for attribution and exactly-once learning updates.
- [ ] Document learning thresholds, confidence and safety bounds.

## EPIC 7 — Richer Ride Coaching

Goal: turn each completed ride into specific, actionable coaching rather than a
generic metric summary.

- [ ] Add structured cadence execution analysis for prescribed cadence ranges.
- [ ] Add interval-level heart-rate response and recovery analysis where data
      coverage is adequate.
- [ ] Add climbing-segment pacing analysis using gradient and elevation samples.
- [ ] Add sprint repeatability and peak-power fade analysis.
- [ ] Add fuelling-plan adherence input to the post-ride check-in.
- [ ] Compare planned versus reported fuelling for long and demanding rides.
- [ ] Generate family-specific positives and improvement cues from validated
      session evidence.
- [ ] Link each improvement cue to the next relevant workout prescription.
- [ ] Add insufficient-data explanations for every new analysis dimension.
- [ ] Add unit tests for cadence, heart-rate, climbing, sprint and fuelling
      analysis with incomplete-data cases.
- [ ] Add widget tests for the expanded post-ride coaching report.
- [ ] Update ride-analysis documentation and evidence requirements.

## EPIC 8 — Proactive Recovery and Nutrition Coaching

Goal: turn recovery and nutrition records into timely actions tied to planned
training demand.

- [ ] Define a daily recovery-action domain model with priority, confidence,
      expiry and supporting evidence.
- [ ] Generate sleep, hydration, mobility and rest actions from tomorrow's
      workout and current recovery state.
- [ ] Define pre-ride, during-ride and post-ride fuelling prescriptions from
      workout duration and intensity.
- [ ] Adjust carbohydrate and hydration targets for forecast temperature and
      expected sweat demand.
- [ ] Add athlete-configurable reminder windows and quiet hours.
- [ ] Schedule server notifications for time-sensitive recovery and fuelling
      actions.
- [ ] Mark actions completed, dismissed or no longer relevant without changing
      historical coaching evidence.
- [ ] Feed adherence into learning only after sufficient repeated observations.
- [ ] Add unit tests for action priority, expiry, weather adjustment and missing
      evidence.
- [ ] Add notification integration tests for timezone and quiet-hour behavior.
- [ ] Add widget tests for completing and dismissing daily actions.
- [ ] Document proactive-action and notification semantics.

## EPIC 9 — Goal Strategy and Forecasting

Goal: show whether current training is closing the gap to the target event and
what trade-offs matter most.

- [ ] Extend event demands with terrain, duration, elevation, intensity pattern
      and fuelling requirements.
- [ ] Add an athlete-facing editor for event-demand assumptions.
- [ ] Map event demands to capability targets with evidence confidence.
- [ ] Calculate goal readiness from current capabilities rather than plan
      completion alone.
- [ ] Forecast capability and fitness ranges to the event date with uncertainty.
- [ ] Detect when remaining availability makes the original goal unrealistic.
- [ ] Generate conservative “stay course”, “reduced load” and “more time”
      scenarios without mutating the plan.
- [ ] Show the main capability gaps and the blocks intended to close them.
- [ ] Add unit tests for demand mapping, readiness and uncertainty bounds.
- [ ] Add widget tests for scenario comparison and event-gap explanations.
- [ ] Document goal-readiness assumptions and non-guarantee language.

## EPIC 10 — Observability, Data Quality and Resilience

Goal: make failures diagnosable and prevent stale or contradictory data from
quietly influencing coaching.

- [ ] Define typed data-freshness and provenance status for every coaching input.
- [ ] Add server checks for duplicate, stale, implausible and conflicting source
      records.
- [ ] Exclude quarantined records from derived metrics while retaining them for
      diagnosis.
- [ ] Add a private sync-health screen showing source freshness, last success,
      queued mutations and delivery failures.
- [ ] Add structured correlation IDs across import, processing, decision and
      delivery jobs.
- [ ] Add privacy-safe server logs and bounded retention for operational events.
- [ ] Add alerting for repeated pipeline, notification and delivery failures.
- [ ] Add database indexes verified against the main athlete timeline queries.
- [ ] Add pagination and lazy sample loading for long activity histories.
- [ ] Add integration tests for stale-data exclusion and pipeline traceability.
- [ ] Add performance tests for multi-year activity history and sample loading.
- [ ] Document operational troubleshooting and recovery procedures.

## EPIC 11 — Quality Gates and Release Safety

Goal: keep autonomous coaching changes safe as the system becomes more capable.

- [ ] Create anonymized golden athlete timelines for normal training, overload,
      illness, taper and missing-data scenarios.
- [ ] Run the same golden timelines through Dart and server coaching engines.
- [ ] Add invariant tests preventing unsafe intensity, excessive recovery chains
      and post-event plan leakage.
- [ ] Add end-to-end tests from imported ride through analysis, learning,
      next-day decision and provider delivery.
- [ ] Add migration rollback guidance and forward-recovery tests for every new
      server schema change.
- [ ] Add automated checks that secrets and private athlete data are absent from
      build artifacts and logs.
- [ ] Add Android smoke tests for upgrade-with-data-preservation.
- [ ] Add web smoke tests for authenticated relational reads and responsive
      navigation.
- [ ] Establish a reproducible release checklist covering tests, analysis,
      Android build, web build, migration status and phone installation.
- [ ] Record the verified test count and production validation date after each
      release milestone.
- [ ] Update `PRODUCT_SPEC.md`, `ARCHITECTURE.md`, `ROADMAP.md` and operational
      documentation when this backlog is completed.

## Deferred beyond this backlog

Voice coaching, live ride control, direct smart-trainer control, computer-vision
bike fit, coach marketplace and team accounts remain intentionally deferred.
They add less value to the current single-athlete coaching loop than the work
above and require separate product approval before entering the engineering
backlog.

## Definition of done

A task is complete only when its implementation, relevant automated tests,
documentation and backlog checkbox agree; analysis is clean; external inputs
are validated; secrets remain outside source control; and no known regression
or unexplained coaching behavior has been introduced.
