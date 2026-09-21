# ARCHITECTURE.md

# CycleReady Architecture

Version: 2.0

---

# Philosophy

CycleReady follows:

- Clean Architecture
- Feature First Organisation
- SOLID Principles
- Repository Pattern
- Dependency Injection
- Riverpod
- Offline First
- AI First

The application should be modular.

Every feature must be replaceable without affecting the rest of the application.

---

# High Level Architecture

```
Presentation Layer

↓

Application Layer

↓

Domain Layer

↓

Data Layer

↓

External Services
```

The Android application starts from `lib/main.dart`. The responsive web client
starts from `lib/main_web.dart` and is built with
`flutter build web -t lib/main_web.dart`. This separate composition root keeps
Android-only plugins out of the browser compilation while allowing shared,
platform-neutral domain and presentation components to be introduced safely.
The web client must consume athlete data through authenticated cloud
repositories; it must never attempt to access Health Connect or the phone's
local SQLite database directly. Supabase/Postgres is the canonical source of
truth for athlete data and coaching state. Drift is an offline cache and a
pending-write store, not an independent coaching database.

The canonical relational schema is introduced by
`supabase/migrations/202608310001_create_adaptive_coaching_platform.sql` and
completed for the v2 contract by
`supabase/migrations/202608310005_complete_v2_cloud_contract.sql`. It
separates source facts (`activities`, `activity_intervals`, `wellness`, FTP and
weight histories), recalculable/versioned outputs (`session_analysis` and
`daily_readiness`), and coaching state (`goals`, `training_blocks`,
`planned_sessions`, and append-only `adaptive_decisions`). The v2 extension
adds event-demand profiles, capability history, phases, weekly plans,
materialized resolved wellness, coaching-state snapshots, calculation/sync run
ledgers, athlete feedback, and notifications. All athlete-owned
rows carry `athlete_id`; RLS resolves that identifier to the authenticated
Supabase user. The shared workout library is authenticated read-only. Provider
tokens are never columns in client-readable tables and must remain in
server-side secret storage.

Intervals.icu authorization is brokered by the `intervals-oauth-start` and
`intervals-oauth-callback` Edge Functions. The start endpoint authenticates the
CycleReady account, stores only a SHA-256 hash of a short-lived one-use state,
and returns the provider consent URL. The callback exchanges the two-minute
authorization code on the server and writes the bearer token to the
RLS-protected `provider_credentials` server-only relation. `intervals-sync`
prefers that OAuth token and athlete `0`, while retaining the personal API key
secret as a single-athlete rollout fallback. Intervals access tokens do not use
refresh tokens; a revoked token requires a new authorization flow.

Postgres Cron invokes `intervals-sync` hourly at minute 17 through `pg_net`.
The scheduler credential is generated inside Postgres, stored in Supabase Vault,
and verified by digest, so it never appears in source control or a client.
A second hourly database job identifies connected providers without a successful
sync for six hours and creates at most one athlete-visible operational alert per
integration per 24 hours. Cron execution history and the integration run ledger
provide separate transport and application-level observability.

On-device plan publication uses deterministic `cycleready-YYYY-MM-DD` external
identities. The sync coordinator fingerprints the 14-day prescription and only
reconciles when it changes. Reconciliation bulk-deletes those future owned
identities before recreating the current non-rest sessions, which both removes
obsolete work and causes downstream provider exports to refresh. Completed days
and provider events outside CycleReady's namespace are excluded.

The deployed `intervals-sync` Edge Function performs authenticated,
phone-independent activity and wellness imports. Provider records retain their
source payload and are upserted by stable provider identity. The
`resolved_daily_wellness` compatibility view selects one coaching input per athlete/day while
preserving every source row: manual entries take precedence, then Health
Connect, then Intervals.icu, with recency breaking ties. The v2
`daily_wellness_resolved` relation materializes that winner with source
attribution and an algorithm version for server processing.

Server processing is split into independently deployable, secret-authenticated
Edge Functions. `process-derived-metrics` writes versioned CTL, ATL, TSB, load
windows/ramp and physiological baselines with source IDs and an idempotent run
ledger. `process-readiness` consumes those records and resolved wellness,
allows illness/pain to override wearable scores, lowers confidence for absent
evidence, and persists both daily readiness and the authoritative athlete-state
snapshot. `process-goal-plan` converts event facts and the latest capability
evidence into an event-demand/gap profile and a versioned phase, block and week
hierarchy. These functions use the service role only inside Supabase; clients
receive RLS-protected reads and cannot author authoritative calculations.

`process-session-analysis` is a two-stage processor. It stores provisional,
workout-family-specific stimulus analysis immediately after import and updates
the same versioned result with recovery cost 12–48 hours later. Pw:Hr remains
null without comparable steady intervals and durability remains null without a
prolonged trace. `process-adaptive-decision` applies health, availability,
equipment, taper, spacing, and recovery-day constraints before candidate
ranking. A database RPC locks the planned session, appends the idempotent
decision, preserves the original workout, and applies its revision atomically.
`process-athlete-capabilities` maintains the 13-dimension capability vector
from the latest 90 days of attributable activity and absorbed-session evidence;
each run can move a dimension by at most five points. Intervals sync records an
idempotent run and invokes the processing chain in dependency order using the
job secret internally, so provider webhooks can advance coaching while the
phone is closed.

### Autonomous daily coaching pipeline

Supabase owns the authoritative daily run. Every 15 minutes the database
scheduler evaluates 05:00â€“05:14 in each athlete's IANA timezone and submits a
versioned athlete/date envelope to `daily-coaching`. The function refreshes
readiness, assembles relational evidence, applies adaptive safety and selection,
and upserts one recommendation for the athlete and local date. An evidence
fingerprint reuses an unchanged answer; materially newer readiness, wellness,
activity or plan evidence permits a same-day recalculation.

Each attempt is recorded independently. Failures store a bounded exponential
retry time, and the retry scheduler submits the same versioned envelope without
blocking activity or wellness imports. Ten attempts is the hard ceiling. Edge
functions own service-role writes; authenticated clients have athlete-scoped
read access only.

Android and web read the persisted recommendation. Android can continue with
its local coaching engine when configuration, authentication, connectivity or
today's server result is unavailable and labels that state on Today. The web
portal does not run a second coaching engine; until a recommendation exists it
continues to show relational recovery and planned-session information.
The Android recommendation provider observes the Supabase account lifecycle,
waits for initial session restoration, and refreshes on authentication changes
or app resume. A transient fetch failure retains the explicit fallback warning
and schedules a 30-second retry while Today remains observed; leaving Today
cancels that timer.
Stored recommendations are reusable only when selected workout type, title,
duration and load match the current server planned session. A mismatch invokes
the idempotent daily pipeline again. Accepted recommendations converge into the
local Drift calendar through `authoritativeDailyPlanSyncProvider`.

Workout delivery state is represented in the coaching domain independently of
Intervals.icu or any future provider. Its validated transitions prevent a
deleted delivery being silently revived, require provider identity for an
acknowledged delivery, and retain explainable failures for retry workflows.
Supabase `workout_deliveries` persists the provider's workout ID, desired and
acknowledged SHA-256 content hashes, desired and acknowledged versions, attempt
count and latest attempt time under athlete-owned RLS. One row exists per
planned-session/provider pair, keeping provider transport state separate from
the coaching prescription.
`WorkoutDeliveryOutboxRepository` accepts provider-neutral create, update and
delete commands carrying a stable idempotency key, content hash and immutable
payload. Supabase stores them in athlete-owned chronological order with a
database uniqueness constraint, due-attempt state and failure fields, allowing
transport workers to retry without duplicating provider mutations.
The scheduled `deliver-workouts` Edge Function atomically claims due commands
with `FOR UPDATE SKIP LOCKED`, discards superseded content hashes and writes to
Intervals.icu using `cycleready-YYYY-MM-DD` as the provider `external_id`.
This is the same canonical identity used by on-device reconciliation and remains
stable when plan regeneration replaces a planned-session UUID. Contract-v2
delivery removes the legacy UUID-keyed event before its canonical upsert, so
existing duplicates converge safely and retries cannot create new duplicates.
For an athlete with account-specific OAuth, Flutter uploads the future plan to
Supabase and does not also publish the calendar with its optional local API key.
The worker lists the affected provider date before each write and deletes only
workout events whose `CycleReady - ` name and canonical or legacy CycleReady
external identity establish ownership. It uses provider event IDs to remove
old API-key and replaced-plan copies, while retaining the canonical event owned
by the configured OAuth client. User-created and other-application workouts are
never selected by this reconciliation.
Provider upsert therefore remains idempotent if a worker stops after the remote
write but before acknowledgement. Failed attempts use bounded backoff; success
updates the delivery only when the desired hash is still current. Android cloud
upload first converges its future local plan, including scheduled time, into the
authoritative rows so status cannot come from an obsolete same-day workout.
An `AFTER INSERT OR UPDATE` trigger on authoritative planned sessions builds a
canonical provider payload and SHA-256 hash. Non-riding and completed entries
are ignored, unchanged hashes are no-ops, and each changed prescription queues
one create or update command. This makes server adaptations queue delivery even
when the phone is closed and uses the same path for athlete selections after
normal plan synchronization.
The trigger is restricted to today and future dates. A changed hash increments
the desired version and chooses `update` once a provider workout ID has been
acknowledged; past prescriptions cannot generate new provider work.
Before a future planned session is deleted, its trigger either cancels an
unacknowledged create or appends a delete command containing the acknowledged
external ID. The delivery audit row uses `ON DELETE SET NULL`, so removing the
plan cannot erase the provider operation or its history.
Every tracked delivery is marked as CycleReady-managed. A database guard rejects
delete commands without both that ownership marker and an acknowledged external
ID, and rejects deletion while a linked session is completed. Provider entries
that CycleReady did not create never enter this deletion path.
Authenticated retry functions verify athlete ownership and limit work to
future sessions whose completion state is still planned. They release the
existing failed outbox command back to `pending`, preserving its idempotency
key rather than creating a duplicate command. Android exposes both a
per-workout retry and a bulk retry for eligible future failures.
The Intervals adapter reads calendar events for the requested local-date range
and maps only `WORKOUT` entries carrying CycleReady stable external IDs.
Provider-neutral reconciliation compares a canonical hash of external ID, date,
name, workout description and duration. A matching hash is current; a missing
ID is stale/missing; and a mismatched hash is externally diverged. Unowned
provider entries are ignored and are never candidates for cleanup.
`WorkoutDeliveryStatusRepository` reads athlete-scoped persisted delivery rows
with their planned date. The application combines those durable states with
the latest live reconciliation result; presentation receives typed statuses
and only renders attention states, keeping comparison and transport logic out
of calendar widgets. Once OAuth delivery is active, the persisted server state
is authoritative: entering that path clears any legacy phone-side comparison,
and an acknowledged `delivered` or `updated` row cannot be overridden by a
stale local mismatch. Server-reported failure or divergence remains visible.

`AuthenticatedAthleteResolver` is the shared cloud ownership boundary. It
requires a Supabase session and resolves `athletes.user_id = auth.uid()` before
any athlete-scoped query; repositories never select an unqualified global
singleton. An `auth.users` trigger creates one athlete row idempotently for
each new account, while the client performs a defensive bootstrap after
immediate sign-in or registration. Password recovery uses the private Android
deep link and updates credentials through the authentication repository.
The secure sign-out controller first removes the account's device push-token
rows, erases every local athlete table including queued mutations, removes
encrypted local provider credentials, and only then closes the cloud session.
If cleanup fails, sign-out stops so the phone cannot silently expose a prior
athlete's cached records to a subsequent account.
Authenticated account deletion is owned by the `delete-account` Edge Function.
It validates the caller's bearer token, deletes only that authenticated
`auth.users` row through the service client, and relies on foreign-key cascades
to remove the athlete, provider credentials, delivery queues and coaching
history. The client then erases its local database and encrypted provider data.
Production isolation validation uses two disposable accounts to prove distinct
athlete bootstrap, owner-only activity reads and rejection of foreign-athlete
writes before deleting both fixtures.
Private Android releases are produced by a tag-triggered GitHub workflow using
one protected keystore. CI validates, signs and publishes an APK plus checksum.
The app compares its package version with GitHub's latest release and offers
the HTTPS APK externally only when the semantic version is newer.

`SupabaseRelationalCoachingRepository` is the shared read boundary for Android
and web. Web portal providers no longer read snapshot JSON. Android Today reads
the versioned `daily_coaching_recommendations` contract through a dedicated
repository and gives it precedence over local planning; a missing, failed or
offline read leaves the existing on-device coaching engine as an explicitly
labelled fallback. Web Today reads the identical repository contract and
renders the authoritative selection without implementing its own coaching
rules. When today's row is absent,
`SupabaseDailyCoachingStatusRepository` invokes `daily-coaching` using the
current Supabase bearer session. The function validates that JWT and proves
athlete ownership before entering its service-role pipeline. Stored and direct
responses map to the same domain contract, with privacy-bounded transport and
parsing diagnostics. FCM remains notification transport only, not coaching
authority.
`apply_adaptive_decision` updates workout identity, family, adaptation, display
title, duration and load in one transaction. The normalized replacement is
also returned in the daily recommendation, preventing Today, Plan and the
delivery outbox from observing different versions of one adapted workout.
Immediate illness, injury and zero-availability safety gates are a
shared server module; server and Dart policies are checked against the same
version-controlled golden scenarios to prevent cross-runtime drift. Drift
schema is independent from the relational `adaptive_decisions` constraint,
which accepts hierarchy levels 0 through 7 so same-purpose reductions,
substitutions, endurance, recovery and rest fallbacks can all be persisted.
An unsupported hierarchy value fails the authoritative job visibly rather
than being silently converted to on-device coaching. Drift
schema 23 adds a durable
pending-mutation queue. Its uploader uses an explicit entity allow-list,
append idempotency, and observed-version comparison; stale edits become visible
conflicts while transport failures remain queued for bounded retry.

`HealthCloudSyncService` converts each successful device read into stable-ID
wellness and activity mutations. Local storage remains authoritative while
offline; `SupabaseMutationUploader` resolves the authenticated athlete at
upload time, adds ownership, and relies on the existing RLS-protected tables.
The coordinator flushes these mutations after provider ingestion so health
data can drive the server coaching pipeline without requiring the phone to
stay online during the original Health Connect read.

Drift schema 24 adds `deleted_activities` tombstones. Completed-activity
deletion is transactional across the activity, samples, feedback and coach
report, while source identifiers and timing are retained to stop provider or
file imports from recreating the activity. Tombstones participate in data
backup, restore and erase operations. Because recovery and training metrics
derive from the observable activity repository, deletion also removes the
ride's load from those calculations without maintaining a second load total.

`ride_duplicate_matcher.dart` is a pure, conservative domain service. It scans
stored activities in start-time order and emits explainable possible pairs only
when close timing and duration have corroborating distance, power or
cross-source evidence. `ActivityRepository` adapts database rows to this
contract, but the scan is intentionally not surfaced as a prominent Cycling
dashboard warning; deletion remains an explicit athlete action.

Recent import notifications route directly to the existing post-ride debrief.
`PostRideFeedbackController` persists the answers and owns next-session
adjustment. Dashboard and local-coach recovery-time consumers observe the
latest recent feedback and pass its effort, leg-fatigue and discomfort values
to the pure recovery estimator. Feedback older than the estimator's 96-hour
activity window cannot change current recovery.

Large second-by-second activity streams are stored separately from the athlete
snapshot in `activity_sample_chunks`. Android orders samples and writes chunks
of at most 500 records through `CloudActivitySampleRepository`, issuing one
bounded PostgREST request per chunk so a long ride cannot recreate a single
oversized TLS upload; the compact
snapshot is committed last so a failed chunk request cannot create a false
cross-device conflict. The web client fetches chunks lazily only when an
authenticated athlete opens a ride. Supabase RLS restricts every chunk by
`auth.uid()` and the compound athlete/activity/chunk key.

Supabase configuration is injected with `CYCLEREADY_SUPABASE_URL` and
`CYCLEREADY_SUPABASE_PUBLISHABLE_KEY` Dart defines. `CloudAuthRepository` owns
account access. Production parity was validated before compatibility snapshot
writes were disabled. The final `athlete_snapshots` row remains an
athlete-readable migration archive; authenticated clients cannot insert, update
or delete it. Android now flushes version-aware relational mutations and
uploads detailed sample chunks, while web and Android coaching reads use only
RLS-protected relational repositories.
Raw second-by-second activity samples are deliberately omitted from the initial
JSONB snapshot because real histories exceed safe mobile request sizes. Ride
headline metrics and coach reports remain available. Detailed sample streams
require a later chunked object-storage transport rather than one oversized
database request.

---

# Folder Structure

```
lib/

app/

core/

features/

shared/

services/

models/

repositories/

providers/

utils/

widgets/

main.dart
```

---

# Feature Structure

Every feature follows exactly the same structure.

```
features/

feature_name/

presentation/

pages/

widgets/

controllers/

providers/

domain/

entities/

repositories/

usecases/

data/

datasources/

models/

repositories/

services/

tests/
```

No feature should directly access another feature's internal code.

Communication occurs through repositories or services.

---

# Core Module

Contains application-wide functionality.

```
core/

constants/

errors/

exceptions/

extensions/

logging/

routing/

theme/

config/

```

Never place feature-specific code inside core.

---

# Athlete Module

Responsible for

Athlete profile

The `AthleteState` domain model is the immutable coaching snapshot that
combines the athlete profile with current fitness, fatigue, freshness,
readiness, recovery and optional trend signals. Calculators and repositories
may produce or persist this snapshot without exposing storage models to
presentation.

`AthleteRepository` is the domain contract for reading, watching and saving
that snapshot. Its implementation belongs in the data layer.

Until durable state persistence is introduced, the data layer provides an
`InMemoryAthleteRepository` for dependency injection and deterministic tests.
`AthleteStateService` coordinates state reads, observation and writes; metric
calculation remains in the relevant domain services.
Durable state metrics are stored in the Drift `athlete_states` table, while
the state profile continues to use `athlete_settings`.
Each saved state is also appended to `athlete_state_history`, which supports
chronological trend reads without replacing the current snapshot.
Athlete-state trend calculation compares the oldest and newest snapshots in a
requested history window and returns no result until two observations exist.
It remains a deterministic domain operation exposed through
`AthleteStateService`.
`ReadinessCalculator` owns deterministic readiness scoring from recovery input;
it returns weighted evidence factors, the aggregate score, the recovery
component score and a recommendation without persistence or presentation
concerns.
The result also exposes a bounded fatigue score from the athlete check-in,
using a neutral value when no check-in is available.
Confidence is derived only from available sleep, recovery and check-in
evidence, so missing inputs reduce the reported confidence.
The activities-domain training metrics model calculates CTL and ATL with
42-day and 7-day exponential time constants, derives TSB and weekly CTL ramp
rate, and classifies overload or detraining only when multiple load signals
agree. A new athlete without an established CTL baseline is never labelled as
detraining.

Body metrics

Goals

FTP

Heart rate

Power curve

Weight

Preferences

Training availability

This is the single source of truth for athlete information.

---

# Ride Module

Responsible for

Ride import

Ride storage

Ride analysis

Ride comparison

Ride summaries

Ride history

`SessionOutcomePolicy` consumes a delivery-neutral session purpose and
normalized external-load, internal-load, subjective and follow-up recovery
evidence. It produces stimulus, recovery-cost and optional durability scores,
a purpose-aware outcome, possible failure causes and the next-session action.
The pure domain service deliberately excludes invalid Pw:Hr evidence and only
permits progression after comparable sessions were both achieved and absorbed.

---

# Workout Module

Responsible for

Workout generation

Workout editing

Workout storage

Workout delivery

Workout history

Workout templates

`WorkoutGenerator` materialises recovery, endurance, tempo, sweet-spot,
threshold, VO2-max, anaerobic, sprint and climbing sessions from a coaching
context. Warm-up and cool-down generation are composable domain services,
`WorkoutValidator` rejects invalid structures before delivery, and format
providers implement the `WorkoutExporter` boundary.

The canonical catalogue contract is defined by `WorkoutFamily`,
`WorkoutVariant`, `WorkoutCatalogueStep` and `WorkoutProgression`. Its stable,
versioned IDs contain no provider or persistence identity. Variants carry
adaptation, duration class, recovery time, phase, terrain, equipment, cadence
and success-criteria metadata; ordered step roles prevent planning, analysis or
delivery code from parsing display strings. `WorkoutCatalogueRepository`
supports provider-neutral family, phase, duration and equipment queries.

`LocalWorkoutCatalogueRepository` adapts the existing phase-aware generator
behind that boundary during migration. Supabase owns the shared versioned
catalogue tables, structured steps and progression edges. They are immutable to
normal clients, readable only when authenticated, and isolated from
athlete-owned plan history. Idempotent migrations seed all families across
three difficulties and short, standard and extended duration classes.

---

# Adaptive Planning Module

Responsible for

Daily planning

Weekly planning

Training phases

Goal events

Periodisation

Adaptive changes

Workout progression

Local event storage is a collection rather than a singleton. Stable device
event IDs synchronize to `goals.client_goal_id`; `(athlete_id,
client_goal_id)` makes retries idempotent while preserving legacy server goals.
The repository selects the highest-priority upcoming A/B/C event as the main
planning target and retains other upcoming events in the generated calendar.
Each event has explicit edit and delete actions.

An accepted adaptive-plan rebuild triggers cloud synchronization immediately.
`SupabasePlannedSessionSyncRepository` upserts by athlete and calendar date,
including origin and prescription evidence. Existing server row identities are
therefore retained, their delivery content hashes change, and the scheduled
delivery worker updates—not duplicates—the corresponding Intervals.icu event.

This module never generates UI.

Only decisions.

`CoachEngine` creates confidence-scored daily and seven-day workout
recommendations from readiness, recovery, training load and athlete power
development evidence. `DecisionEngine` owns the lower-level safety decision
thresholds. Event and multi-week planning remain delegated to
`AdaptivePlanGenerator`, keeping orchestration separate from plan generation.
Current readiness, form and ramp-rate recovery gates are scoped to the next two
generated cycling sessions; future sessions return to phase-led periodisation.
Planned recovery weeks, explicit protected dates and the recovery-day limit
remain independent safety constraints.

Strategic planning is represented by the provider-neutral contracts in
`strategic_training_plan.dart`. `EventDemandModel` normalizes event type,
distance, expected duration, elevation and terrain into the same capability
dimensions used by `AthleteCapabilityProfile`. `StrategicTrainingPlanner`
calculates confidence-weighted event gaps, selects a dynamic phase and creates
an explicit primary/secondary/maintenance block intent. Only then may
`WorkoutFamilyEligibilityEngine` construct a weighted family pool. Readiness
is deliberately absent from these strategic types: it modifies the dose after
the intended adaptation and eligible families have been established. The
server remains authoritative. `process-goal-plan` imports the matching shared
server policy, persists per-dimension gaps and confidence, creates dynamic
Foundation/Base/Build/Specialty/Taper segments, and stores ordered weekly
adaptation objectives before any individual workout is assigned. Phase lengths
respond to event proximity, the size of the leading capability gap, and recent
training consistency; they are not fixed percentages. These pure Dart
contracts support deterministic tests and the safe offline fallback.

`process-adaptive-decision` constructs this strategic family pool before its
readiness and suitability ranking. Phase, block-primary, block-secondary,
maintenance and event-demand weights are logged with rejected families and
persisted in the decision evidence. A high morning-readiness value therefore
cannot open a workout family that the current block made ineligible.
When a change is necessary, candidates are evaluated in minimum-change order:
smaller same-family dose, lower same-family level, same adaptation, related
lower-stress adaptation, endurance, recovery and finally rest. Harder variants
remain excluded until at least two comparable sessions were both achieved and
absorbed. The offline planner mirrors Foundation behavior: a distant event
uses aerobic/tempo development rather than repeated threshold sessions, and a
fourth-week recovery block is created only when recovery evidence supports it.

`UnplannedWorkoutSelectionService` is the pure domain selector used for empty
calendar days. It evaluates immutable, FTP-scaled recovery, endurance, tempo,
sweet-spot, threshold, VO2-max, climbing, anaerobic and sprint candidates from
the canonical selection context. Ranking exposes additive score components,
confidence and rejection reasons; deterministic family ordering resolves equal
scores. `WorkoutBrowserController` applies family and duration presentation
filters without changing eligibility, so rejected candidates can be explained
but never selected. Presentation groups options by adaptation and delegates
persistence to `PlannedSessionController`, preserving the UI -> controller ->
domain -> repository dependency direction.
`AdaptiveTrainingPolicy` is the deterministic policy boundary above those
planning primitives. Application providers normalize repository data into its
immutable input; the policy returns an immutable, JSON-serializable decision
with athlete state, evidence confidence, adaptation scope, standardized reason
codes, safety outcome, FTP-review flag and next-72-hour effect. It performs no
persistence and never reads presentation or data-layer types.

---

# Readiness Module

Responsible for

Sleep

HRV

Recovery

Fatigue

Body Battery

Stress

Readiness Score

Recovery recommendations

---

# AI Coach Module

Responsible for

Natural language coaching

Ride summaries

Daily briefing

Workout explanations

Motivation

Recommendations

Question answering

This module never calculates metrics.

It interprets them.

---

# Nutrition Module

`FoodCatalogueRepository` separates food lookup from presentation.
`OpenFoodFactsRepository` merges a validated bundled offline catalogue with
read-only Open Food Facts results and falls back locally on timeout or invalid
data. `FoodCatalogueItem` owns serving-size scaling. Catalogue selections are
saved through `NutritionEntryController`, preserving the existing entries,
favourites, backup and cloud synchronization paths.
`FoodBarcodeScannerScreen` recognizes retail EAN/UPC codes on-device, then
passes only the decoded number through `FoodCatalogueRepository.findBarcode`.
Product lookup remains read-only and missing products return an explicit
fallback; the scanner never guesses nutrition from a barcode.

Responsible for

Calories

Protein

Carbohydrates

Hydration

Meal timing

Ride fuel

Recovery nutrition

Weight trends

---

# Body Composition Module

Responsible for

Weight

Body fat

Muscle mass

Waist

Trend analysis

Body recomposition

---

# External Services

```
Health Connect

↓

Garmin

↓

Strava

↓

Intervals.icu

↓

Weather API

↓

OpenAI

↓

Renpho

```

Every service must have

Datasource

Repository

Mapper

Model

Error handling

Retry logic

Weather is accessed through `WeatherRepository`; the current Open-Meteo data
implementation geocodes the athlete's location and requests hourly forecasts.
Deterministic domain rules—not the HTTP client—decide whether an outdoor
workout should move indoors. Forecast failures fall back to the unmodified
offline plan.
`CachedWeatherRepository` decorates the remote implementation and persists the
last successful preferred-time result through `WeatherCacheStore`. It may serve
a cached result for offline presentation for up to 36 hours. Forecast metadata
includes its fetch time and cache origin; application services treat data older
than six hours as stale and never pass it into workout-adjustment rules.
The athlete profile persists a riding-safety profile. Weather-domain thresholds
translate that profile into deterministic limits, while a weather application
provider supplies the preferred-time Today forecast without exposing the API to
presentation code.

---

# Repository Pattern

Presentation

↓

Controller

↓

Repository

↓

Datasource

↓

API / Local Database

Presentation never talks directly to APIs.

Planned-session and training-preference reads and writes are owned by the
coaching repository. Calendar providers and the planned-session controller use
that abstraction; Drift companions are constructed only in the data layer. The
training-plan presentation obtains athlete targets and preferences from feature
providers and never reads the database provider directly.

Goal events use a coaching-domain entity and repository. Periodisation,
adaptive planning and daily coaching context therefore depend on the domain
contract rather than Drift's generated event row.

Body measurements use a body-domain entity and repository for manual,
Bluetooth, CSV and Health Connect records. New measurements update current
weight through the athlete-profile controller, keeping the athlete model as the
single coaching source while measurement history remains available for trends.

Learned workout responses use a coaching-domain snapshot and repository. The
repository also owns the processed state of coaching decisions so a completed
session contributes to the athlete model exactly once.
Once at least three comparable sessions exist, learned completion, delivered
load and leg-fatigue responses can conservatively reduce, maintain or progress
the future dose with an explicit reason and sample-based confidence. Personal
insights may also test matched sleep, nutrition and body-weight relationships;
body associations are coaching evidence and never weight-loss prescriptions.

Planned-workout matching is a deterministic coaching-domain service. Activity
import sources remain irrelevant to the matcher; application adapters supply
normalized plan and ride candidates and consume the confidence-scored match.
Matched interval execution is calculated in the activities domain from
normalized expected segments and power samples. An application adapter maps a
structured coaching workout into those segments, preserving feature boundaries;
the persisted coach report consumes only the resulting analysis.

---

# State Management

Use Riverpod.

Every feature owns its providers.

Avoid global mutable state.

Keep providers focused.

---

# Local Database

Store

Athlete

Rides

Workouts

Recovery

Goals

Nutrition

Settings

AI history

Ride analysis

Future plans

Use Drift or Isar.

Repositories hide implementation.

---

# Networking

Use Dio.

Centralise

Authentication

Logging

Retry

Timeouts

Error handling

Caching

---

# Dependency Injection

Inject

Repositories

Services

AI clients

Database

Storage

Preferences

Never instantiate dependencies inside widgets.

---

# Models

Separate

Entity

DTO

Database Model

API Model

Never reuse one model for every layer.

---

# Error Handling

Create

Failure

Exception

Result

Types

Never throw raw exceptions through the application.

---

# Logging

Log

API requests

Workout generation

AI decisions

Errors

Performance

Sync operations

---

# AI Engine

The AI never owns data.

The AI receives structured context.

Example

Athlete

↓

Recovery

↓

Ride History

↓

Workout

↓

Goal

↓

Prompt Builder

↓

LLM

↓

Coach Response

The LLM should only reason.

Business logic belongs in the application.

---

# Workout Delivery

The planner creates a Workout object.

Delivery providers implement

```
WorkoutProvider

sendWorkout()

updateWorkout()

deleteWorkout()

supportsRealtime()

supportsCalendar()

```

Providers

Intervals.icu

Garmin (future)

FIT Export

Zwift

Mock

Planning code must never know which provider is active.

---

# Prompt Builders

Separate prompt generation from AI clients.

```
PromptBuilder

↓

OpenAI Client

↓

Coach Response

```

Prompt builders should be testable.

---

# Background Jobs

Support

Morning readiness calculation

Workout generation

Ride import

Workout sync

Future training providers implement the provider-neutral
`TrainingProviderAdapter` contract and declare activity, wellness, calendar or
webhook capabilities explicitly. `TrainingProviderSyncOrchestrator` passes
opaque per-provider cursors, validates returned data against those capabilities
and isolates failures so one unavailable provider cannot stop the others.
Calendar reconciliation is likewise a coaching-domain capability rather than
an Intervals-specific dependency.

Weather update

Recovery calculation

Notifications

Background jobs must survive app restarts.

The app sync coordinator persists its last success, consecutive failure count
and next retry time in secure storage. Failures use a bounded exponential
policy; a foreground timer performs the due retry while the saved timestamp
prevents an app restart from bypassing backoff. Presentation observes immutable
sync state and never invokes individual external services directly.

---

# Notifications

Android registers its FCM token in the RLS-protected
`device_push_tokens` relation. The scheduled `deliver-notifications` Edge
Function reads due server notifications with the service role, authenticates
to the FCM HTTP v1 API, delivers to each athlete device and removes expired
tokens. Foreground messages use the existing native notification channels;
tap routes are restricted to an explicit in-app allow-list. Push failure never
blocks health, plan or provider synchronization.

Examples

Workout ready

Recovery update

Ride analysed

Hydration reminder

Goal event reminder

---

# Testing

Every feature should include

Unit tests

Widget tests

Repository tests

Use case tests

Integration tests

Mock external APIs.

Database migrations are tested against file-backed SQLite fixtures representing
prior production schemas. Tests seed realistic records, open the fixture through
the current `AppDatabase` migration strategy and verify both current schema
version and retained domain data.

---

# Performance

Avoid rebuilding large widgets.

Lazy load data.

Cache expensive calculations.

Optimise lists.

Optimise AI requests.

Batch API calls.

---

# Security

Store secrets securely.

Never hardcode keys.

Encrypt sensitive data.

Use secure storage.

---

# Future Modules

Voice Coach

Live Ride Coaching

Indoor Trainer Control

Computer Vision

Nutrition Scanner

Bike Fit

Race Strategy

Coach Marketplace

Team Accounts

---

# Architecture Rules

Presentation never accesses APIs.

Business logic never lives inside widgets.

AI never calculates fitness metrics.

Repositories abstract data sources.

Features remain independent.

No circular dependencies.

No duplicated logic.

Prefer composition.

Keep files small.

Keep methods focused.

Document public APIs.

Maintain backward compatibility.

---

# Definition of Good Architecture

A developer should be able to remove an entire feature without affecting unrelated features.

A repository implementation should be replaceable without changing business logic.

The AI provider should be replaceable without changing the coaching engine.

Workout delivery should be replaceable without changing the planner.

Every module should have one responsibility.

The architecture should support continuous growth for many years.
