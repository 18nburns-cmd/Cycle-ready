# ARCHITECTURE.md

# CycleReady Architecture

Version: 1.0

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
The web client must consume athlete data through an authenticated cloud-sync
repository; it must never attempt to access Health Connect or the phone's local
SQLite database directly.

Large second-by-second activity streams are stored separately from the athlete
snapshot in `activity_sample_chunks`. Android orders samples and writes chunks
of at most 500 records through `CloudActivitySampleRepository`; the compact
snapshot is committed last so a failed chunk request cannot create a false
cross-device conflict. The web client fetches chunks lazily only when an
authenticated athlete opens a ride. Supabase RLS restricts every chunk by
`auth.uid()` and the compound athlete/activity/chunk key.

Supabase configuration is injected with `CYCLEREADY_SUPABASE_URL` and
`CYCLEREADY_SUPABASE_PUBLISHABLE_KEY` Dart defines. `CloudAuthRepository` owns
account access and `CloudSnapshotRepository` owns cross-device state. The
initial `athlete_snapshots` JSONB transport is schema-versioned so the existing
backup mapper can evolve without coupling web presentation to Drift rows. RLS
restricts every select, insert, update and delete operation to `auth.uid()`;
anonymous clients receive no table access and secret/service keys are forbidden
in either client application.
`CloudSyncService` creates schema-versioned payloads through the database export
boundary. An upload is allowed only when no remote snapshot exists or its
timestamp matches the last version observed by that device; unseen remote data
is surfaced as a conflict and never silently overwritten. The web summary
mapper reads the neutral payload without importing Drift and keeps absent
health metrics unknown rather than synthesising values.
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

---

# Workout Module

Responsible for

Workout generation

Workout editing

Workout storage

Workout delivery

Workout history

Workout templates

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

This module never generates UI.

Only decisions.

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
