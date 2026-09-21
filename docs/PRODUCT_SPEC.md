# PRODUCT_SPEC.md

# CycleReady Product Specification

Version: 2.0

Author: Neil

Status: Living Document

Governing contract: Adaptive Cycling Coach Master Implementation Specification
v2.0. This document is its CycleReady product translation; the ordered delivery
status is maintained in `TODO.md` and the implementation assessment in
`V2_GAP_ANALYSIS.md`.

---

# Vision

CycleReady is an AI-powered cycling coach.

Supabase/Postgres is the platform source of truth. Android, web and future
clients use the same athlete, activity, wellness, readiness, training-plan,
session-analysis and coaching-decision records. Android may cache records and
queue writes offline, but coaching state must converge through the backend and
must not depend on the phone remaining open.

It is not a cycling computer.

It is not another ride analysis application.

It is not another workout library.

CycleReady exists to coach one athlete every day.

The application should think, learn and make decisions exactly like an experienced cycling coach.

Every recommendation must be personalised.

Every recommendation must be explained.

Every daily workout recommendation must show a confidence score and the
specific athlete evidence used to make the decision. Missing health, check-in
or training-history data must reduce confidence rather than being invented.

Every recommendation must improve long-term performance.

The authenticated web dashboard is available through GitHub Pages and reads
the same per-athlete relational Supabase records as Android. Its first production read
was validated with ride totals, distance, duration, load, FTP, weight and HRV.
Detailed second-by-second ride traces remain a separate cloud-storage
milestone so large sample streams do not destabilise headline synchronization.

Detailed web ride analysis loads ordered sample chunks on demand and displays
power, heart rate, cadence, elevation and a privacy-preserving route trace.
Rides without uploaded samples explain how to complete Android cloud sync
instead of inventing charts or silently showing empty values.

The production detailed-sample path was validated on Android and GitHub Pages:
an authenticated phone upload populated the RLS-protected chunk table, and the
same athlete opened real power, heart-rate, cadence, elevation and route views
from a recent ride on the web.

The web portal provides five responsive sections. Today combines current
training, recovery, body and intake signals; Performance exposes recent rides,
load, FTP and power-to-weight; Calendar combines completed and planned work;
Wellness charts sleep, HRV, resting heart rate, check-ins and weight; Nutrition
compares recorded calories, macros and water with the app's daily targets.

Authoritative coaching reads now come from relational Supabase records on both
web and Android. The same immutable adaptive-decision object carries the action,
original and replacement workouts, reason codes, explanation, confidence, and
model version. Offline client mutations are queued durably; append-only records
are idempotent, edits require the last observed server version, and conflicts
are surfaced rather than silently overwriting newer data.

---

# Mission

Create the world's smartest AI cycling coach.

The coach should continuously learn from:

• Ride history

• Health data

• Body composition

• Recovery

• Training load

• Goal events

• Historical responses

The coach becomes more intelligent after every ride.

---

# Core Principles

The athlete should never wonder:

"What workout should I do today?"

The AI decides.

The athlete should never wonder:

"Am I recovering?"

The AI explains.

The athlete should never wonder:

"Am I improving?"

The AI demonstrates the evidence.

---

# Primary Features

## Athlete Profile

Bike equipment, trainer access, preferred ride time, nutrition preferences and
injury considerations are coaching constraints. The adaptive planner must not
prescribe an indoor-only session when no indoor trainer is available.

Store

Age

Height

Weight

FTP

Critical Power

Power Curve

Heart Rate Threshold

Max Heart Rate

Resting Heart Rate

Weight History

Body Fat

Muscle Mass

Goals

Training Days

Bike Details

Power Meter

Indoor Trainer

Preferred Ride Time

Nutrition Preferences

Equipment

Injury History

Experience Level

Season Goals

---

## Adaptive Coach

Adaptive decisions follow the versioned CycleReady coaching policy. Every
evaluation classifies athlete state and data confidence, chooses the smallest
effective adaptation level, returns standard reason codes and explains the
expected next-72-hour effect. Symptoms override wearable scores; isolated low
readiness cannot rebuild a plan; progression requires repeated successful
training with normal recovery; and taper, availability and hard-session spacing
are protected. FTP review is a separate output requiring multiple independent
signals.

Current-day readiness, form and load-ramp warnings protect only the next two
planned cycling opportunities. They must not flatten the remainder of a
multi-week block into recovery work; planned recovery weeks and explicit
day-specific safety constraints continue to apply across their full scope.

The athlete's normal four-day microcycle places easier aerobic work on Monday,
the primary interval session on Wednesday, controlled secondary intervals on
Saturday and the long endurance ride on Sunday. Adaptive safety may reduce any
of these sessions, but generic session sequencing must not erase this weekly
rhythm when the athlete is ready.

When a calendar day has no planned workout, the athlete can choose from an
FTP-scaled catalogue derived from current readiness, form, load ramp and
demanding work in the previous 48 hours. Recovered athletes can compare
endurance, durability, sweet-spot, threshold, VO2-max, climbing-strength,
anaerobic and sprint variants; moderate readiness exposes tempo without the
highest intensities; constrained days expose only safe recovery and endurance
options. Candidates are ranked from block intent, capability gaps, readiness,
form, ramp rate, prior family-specific success and recovery cost. Every
evaluated candidate retains its score components, confidence and explicit
rejection reasons. The browser groups choices by adaptation, filters by family
and duration, explains why the best fit outranks alternatives and keeps unsafe
choices visible but unavailable. A custom workout remains available.

The planner must not schedule more than two consecutive recovery sessions
unless the athlete is in a planned recovery week, readiness has remained below
45 for two consecutive days, HRV has remained below personal baseline for
three consecutive days, resting heart rate has remained elevated for three
consecutive days, illness/injury is present, or the previous workout's Recovery
Cost Score exceeded 80. Without one of these exceptions, the third recovery
session becomes a short, genuinely easy aerobic session rather than intensity.

Outdoor planning uses the athlete's saved training location and preferred ride
time. Forecast hazards such as near-freezing conditions, extreme heat, heavy
rain, thunderstorms or dangerous wind gusts move an outdoor workout indoors
when a trainer is available. Forecast failure must not prevent offline plan
generation, and every weather adjustment must explain why it was made.
Today shows the forecast at the athlete's preferred ride time. The athlete may
choose cautious, balanced or resilient outdoor-safety limits; the same saved
profile drives both the visible status and adaptive planning decision. The last
successful forecast remains visible offline with its update time. Forecasts
older than six hours are visibly marked as cached/stale and must never change a
planned workout; cached forecasts expire completely after 36 hours.

Every day analyse

Fitness

Fatigue

Freshness

Readiness

Weather

Training Availability

Previous Ride

Upcoming Goal Event

Recovery

Motivation

Then decide

Should today's workout remain?

Should it change?

If yes

Generate a better workout.

Explain why.

---

## Readiness Engine

Calculate

Recovery Score

Readiness Score

Fatigue Score

Readiness results expose recovery and fatigue component scores alongside an
evidence confidence score. Confidence is reduced when sleep, recovery or
check-in evidence is missing; the coach must not present missing signals as
measured facts.

Training Stress

Sleep Quality

Body Battery

HRV Trend

Weight Trend

Recovery Trend

Output

Ready

Caution

Recovery Required

Performance Opportunity

---

## Workout Generator

Future adaptive workouts must be regenerated when the athlete's FTP changes.
Power targets remain percentage-based for delivery, while displayed watt ranges
must reflect the latest athlete profile. Completed and manually planned sessions
must not be rewritten.

CycleReady owns one provider-neutral, versioned workout catalogue. Stable IDs
identify a workout family and variant independently of its display name,
database row or delivery provider. Each variant stores difficulty, duration
class, adaptation target, expected recovery, suitable phases, terrain and
equipment constraints, success criteria, and explicit warm-up, work, recovery
and cool-down steps. Short, standard and extended doses retain the same primary
adaptation. Progression and regression links are explicit and must never be
inferred from titles. Authenticated clients may read the server catalogue;
catalogue mutation remains a trusted server operation.

Support

Recovery

Zone 1

Zone 2

Tempo

Sweet Spot

Threshold

VO2 Max

Anaerobic

Sprint

Neuromuscular

Cadence

Climbing

Race Simulation

Strength Endurance

Workout Structure

Warm Up

Intervals

Recoveries

Cool Down

Coach Notes

Expected Adaptation

Estimated Recovery

Confidence

---

## Ride Analysis

Important completed workouts receive three separate coaching assessments:
stimulus achievement, recovery cost over the following 12–48 hours, and
durability where prolonged steady work makes that measure valid. Classification
is purpose-aware and distinguishes achieved work from achieved work with an
excessive cost. Pw:Hr is omitted when power/heart-rate coverage or ride
structure makes early and late sections incomparable. Progression requires two
or more prior comparable sessions plus the current achieved-and-absorbed
session; one excellent workout never triggers progression by itself.

Imported rides are matched to planned workouts using calendar proximity,
session-name evidence, duration and training load. Adjacent-date matching
requires supporting name evidence so late-night imports are recognized without
silently pairing an unrelated commute or recovery activity. The resulting
match drives compliance learning and the persisted coach report.
When a matched ride has sufficiently complete power samples, post-ride analysis
compares each structured work interval with its current FTP-based watt range.
It reports completed intervals, target accuracy and first-to-last fade, naming
missed targets with actual versus prescribed power. Incomplete traces must be
reported as insufficient rather than scored as failed execution.

Stored rides are scanned for possible cross-source duplicates using close start
time and duration plus corroborating distance, power or source evidence. The
scan must not interrupt the main Rides dashboard with a prominent warning and
CycleReady must never delete a possible duplicate automatically. Deleting a completed
ride removes its load from recovery and training calculations immediately and
retains a tombstone so a later provider sync cannot restore it.

A recent imported ride prompts the athlete to complete the short post-ride
check-in. Perceived effort, leg fatigue and discomfort extend the visible
recovery-time estimate when warranted and can safely reduce the following
workout; unanswered feedback is treated as missing rather than invented.

Analyse

Execution

Power

Heart Rate

Cadence

Pacing

Interval Consistency

Power Drift

Heart Rate Drift

Training Load

Variability

Intensity

Climbing

Descending

Sprint Performance

Time In Zones

Compare against historical rides.

Explain

What improved

What declined

What limited performance

How to improve

---

## Long-Term Learning

The AI should learn

How the athlete responds to

Threshold

VO2

Sweet Spot

Long Rides

Recovery Rides

Strength Training

Poor Sleep

Heat

Travel

Illness

Weight Changes

Nutrition

Hydration

Automatically improve coaching.

---

## Goal Events

The athlete may maintain multiple dated events. A/B/C priority and event date
determine strategic importance: the next A event governs the main development
arc, while intervening B and C events are retained as tune-up or lower-priority
demands without replacing that arc. Events can be edited or deleted
individually; deleting one never removes completed rides.

Generating an adaptive plan is one synchronization operation. After the phone
accepts the new future plan, events and workouts converge to Supabase and the
idempotent delivery outbox updates the same Intervals.icu provider records.
The athlete must not need a separate manual cloud upload merely to make an
adaptive workout change reach Intervals.icu.

When server OAuth delivery is configured, its acknowledged delivery state is
authoritative. A stale comparison produced by the legacy phone-side API-key
publisher must never label an already delivered or updated workout as changed
in Intervals.icu. Genuine server-reported failures, missing workouts and
external divergence remain visible and recoverable.

Support

Sportives

Gran Fondos

Time Trials

Road Races

Audax

Training Camps

Century Rides

Automatically build backwards.

Base

Build

Peak

Taper

Recovery

Automatically adapt.

---

## Nutrition

Food logging provides a searchable food-and-drink catalogue. Common cycling
foods and drinks remain available offline, while online search adds branded
products with nutrition supplied by Open Food Facts. Selecting an item fills
calories, carbohydrate, protein, fat and hydration automatically; changing the
serving amount scales every value consistently. Any result can be saved to the
existing personal library for one-tap reuse, and network failure must never
remove the bundled catalogue or manual-entry fallback.
The phone camera scans EAN-8, EAN-13, UPC-A and UPC-E package barcodes and
looks up the matching product without requiring an account or API key. A found
product enters the same portion and favourite flow as text search. An unknown
barcode clearly offers another scan or name/label entry instead of inventing
nutrition values.

Daily recommendations

Calories

Protein

Carbohydrates

Fat

Hydration

Electrolytes

Ride Fuel

Recovery Fuel

Body Composition

Meal Timing

Recommendations should support

Performance

Recovery

Body Composition

---

## Recovery

Analyse

Sleep

HRV

Stress

Body Battery

Muscle Fatigue

Ride History

Nutrition

Hydration

Recovery Time

Generate

Recovery advice

Mobility

Stretching

Rest

Easy Ride

Hard Ride

---

## Body Composition

Track

Weight

Body Fat

Muscle Mass

BMI

Waist

Trend

Focus on

Body recomposition

Performance

Power to Weight

Never encourage unhealthy weight loss.

---

## Performance Dashboard

Performance Insights includes a rolling 12-week coaching review. It compares
the current training block with the preceding 12 weeks across load, active-week
consistency, HRV and resting heart rate. The review must expose its data
confidence and turn the comparison into a small set of practical priorities;
missing recovery evidence must be stated rather than inferred.

Display

Fitness

Fatigue

Freshness

FTP

Power Curve

Training Load

Power to Weight

Recent Improvements

Current Goals

Training Consistency

---

## AI Coach

The AI should communicate naturally.

Example

Good morning Neil.

Recovery looks excellent.

Yesterday's endurance ride created only moderate fatigue.

Today I'd like to progress your threshold session from 3 × 10 minutes to 3 × 12 minutes.

Confidence 94%.

Reason

Good sleep

Normal HRV

Recovered legs

Goal event in 32 weeks.

---

## After Every Ride

Persist the coach report against the activity so planned-workout comparison,
execution score, confidence, key focus and tomorrow recommendation remain
available after an app restart and are included in backup and privacy controls.

Generate

Coach Summary

Execution Score

Power Analysis

Heart Rate Analysis

Cadence Analysis

Fatigue Analysis

Recovery Advice

Three Positives

Three Improvements

Coach Recommendation

Tomorrow's Recommendation

Confidence

---

# User Experience

CycleReady supports a responsive web dashboard for viewing coaching, calendar,
performance, ride, wellness and nutrition information on a larger screen. The
web application has a dedicated entry point so Android-only integrations such
as Health Connect, Bluetooth devices, notifications and on-device AI remain on
the phone. Personal information must not appear on the web until authenticated,
encrypted cloud synchronisation is configured; the Android app remains the
collector for phone-only health sources.
Cloud synchronization uses athlete-isolated relational records with
version-aware offline mutations. Once signed in, the web overview displays real
ride totals, training load, FTP, weight and HRV from those records and labels
unavailable metrics instead of estimating them.
Cloud account and upload controls live in Connect. Authentication uses the
configured Supabase publishable client key while database row-level security
restricts every record to its signed-in athlete. The compatibility snapshot
transport supports separate private accounts: each authenticated user owns
exactly one athlete profile and password recovery returns through a CycleReady
application link. Cloud repositories resolve that owned athlete explicitly
and never assume the project contains only one athlete. Logout and account
changes must prevent local health or provider data crossing between people.
Signing out is therefore a destructive local privacy operation with explicit
confirmation: cloud records remain, while cached athlete records, pending
uploads, device notification registration and provider credentials are removed
before another person can sign in.
Data & privacy also provides typed-confirmation account deletion, restricted
to the authenticated user. Private distribution uses consistently signed,
checksummed APK releases; Connect offers a trusted newer release without
uninstalling the app or deleting local records.
The compatibility snapshot
transport was retired after production relational parity validation on 2
September 2026; its final row remains a read-only migration archive.

Connected-service sync must preserve offline data when a provider is
unavailable. Temporary failures use bounded exponential retry, persist the next
attempt across app restarts and expose last-success and retry status in Connect.
The athlete can retry immediately without waiting for the automatic schedule.
Today remains focused on coaching, readiness, weather and the day's activity
rather than duplicating connection-management status.
Internal adaptive-decision records remain available to the coaching engine but
are not presented as a separate technical card on Today; their useful outcome
is expressed through the workout and plain-language coaching shown there.
Android Today uses the server's daily recommendation when one exists, including
an explicit rest decision, without showing a redundant success-status card.
While it checks, and whenever the server is
unavailable or has no recommendation for today, the app labels its safe
on-phone coaching fallback so the athlete always knows which calculation is
being shown.
When an authenticated athlete has no stored recommendation for today, Android
invokes the authoritative `daily-coaching` endpoint and consumes its versioned
response before falling back. Endpoint, HTTP status, timeout or network
failure, authenticated user and athlete IDs, bounded response/error body,
schema parsing failure and the fallback condition are recorded in the device
diagnostic log. Firebase Cloud Messaging delivers notifications only; it is
not an authoritative coaching data source.
Today waits for the restored cloud account before its first authoritative read.
If that read fails transiently, the visible fallback remains truthful while the
app retries after 30 seconds; authentication changes and returning to the app
also refresh the request. A successful server read immediately regains
authority without requiring the athlete to restart the app.
Web Today reads that same versioned recommendation and presents its selected
workout or rest day, coaching explanation and confidence instead of deriving a
second answer from the portal's summary data.

Health Connect synchronization persists locally first, then queues idempotent
relational wellness and cycling-activity writes for the authenticated athlete.
Sleep, HRV, resting HR, weight and source provenance reach the server during
the same normal sync cycle; failed uploads remain in the durable retry queue.
Activities the athlete has deleted remain excluded from cloud upload.

Intervals.icu supports provider-approved OAuth for cloud synchronization.
Authorization codes and bearer tokens are handled only by server functions;
the mobile or web client never receives the provider client secret or stored
access token. Consent requests cover activity read, wellness read, calendar
write and settings read. Webhook requests are independently authenticated and
mapped through the provider athlete identity before processing.
Intervals.icu synchronization also runs hourly without the phone being open.
Workout delivery has an explicit provider-neutral lifecycle: pending,
delivered, updated, deleted, failed, or externally diverged. Failed and
diverged states require athlete attention; provider-acknowledged delivery and
updates retain the external workout identity, and deletion is terminal.
The backend claims due delivery commands every two minutes. Provider writes
use the canonical `cycleready-YYYY-MM-DD` external ID and upsert semantics, so
plan-row replacement or retry after a timeout cannot create duplicate workouts.
Legacy UUID-keyed CycleReady events are removed during an idempotent repair
before the newest prescription is upserted. Phone-created plans converge to the
authoritative calendar, including scheduled time, before queued delivery.
When OAuth is connected, the phone must not also write workouts through its
optional API-key connection. Before an authoritative write, the server removes
same-day legacy CycleReady events by their provider IDs, including copies made
under the older API-key integration, while leaving unowned workouts untouched.
CycleReady reconciles its future calendar with Intervals.icu by the stable
external ID it assigned and a canonical content hash. Missing or externally
edited workouts are detected without matching by title or touching entries
created by the athlete or another application.
The Android training calendar marks delivery problems on the affected date and
explains whether a workout is waiting, failed, missing from Intervals.icu, or
was changed externally. Normal synchronized workouts do not add visual noise.
If a connected provider has no successful synchronization for six hours, the
backend creates a deduplicated operational alert for the athlete.
Additional providers must integrate through the shared capability contract for
activity import, wellness import, calendar delivery and webhooks. Provider
failures are isolated, cursors remain provider-owned, and coaching logic never
depends on a provider-specific payload.
When the phone adapts a future plan, its normal connected-service sync
reconciles the next 14 days of CycleReady-owned Intervals.icu events. Obsolete
events are removed and changed workouts are recreated so downstream Garmin and
MyWhoosh delivery receives the revised workout rather than retaining a stale
export. Completed days and non-CycleReady calendar entries are never removed.

The athlete can press and hold a completed activity in Training Plan and
confirm its deletion. This removes the local activity, samples, feedback and
coach analysis. CycleReady retains a deletion marker so subsequent Health
Connect, Intervals.icu or FIT imports do not restore the unwanted activity;
the original record in the source provider is not deleted.

App upgrades must migrate the existing on-device database in place. Athlete
profile, ride history and previously supported settings must survive schema
changes; newly introduced preferences receive safe defaults.

The application should feel like messaging a real coach.

Server coaching notifications are delivered to registered Android devices even
when CycleReady is not open. Notification taps may open only approved in-app
destinations, and notification permission or registration failure must never
prevent normal coaching synchronization.

Avoid dashboards full of numbers.

Explain

Why

How

What next

---

# AI Philosophy

The AI should never simply describe data.

It should interpret.

Predict.

Coach.

Teach.

Encourage.

Adapt.

---

# Success Metrics

The athlete should

Improve FTP

Improve Power to Weight

Reduce Body Fat

Maintain Health

Remain Injury Free

Achieve Goal Events

Understand WHY every recommendation was made.

---

# Future Roadmap

Version 1

Adaptive Training

Ride Analysis

Readiness

Nutrition

Body Composition

Intervals.icu Integration

---

Version 2

Garmin Training API

Live AI Coaching

Voice Coach

Indoor Trainer Control

Automatic FTP Detection

Automatic Illness Detection

Automatic Periodisation

---

Version 3

Computer Vision Bike Fit

Race Strategy

Pacing Assistant

AI Nutrition Planning

Wear OS

Android Auto

Team Coaching

---

# Definition of Success

CycleReady should feel less like software and more like an elite cycling coach.

The athlete should trust its decisions.

The athlete should no longer need to decide what training to do.

Every day the AI should know the athlete slightly better than the day before.
