# PRODUCT_SPEC.md

# CycleReady Product Specification

Version: 1.0

Author: Neil

Status: Living Document

---

# Vision

CycleReady is an AI-powered cycling coach.

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
Cloud uploads contain a complete schema-versioned CycleReady snapshot. A device
must not overwrite a cloud version it has not previously observed. Once signed
in, the web overview displays real ride totals, training load, FTP, weight and
HRV from that snapshot and labels unavailable metrics instead of estimating
them.
Cloud account and upload controls live in Connect. Authentication uses the
configured Supabase publishable client key while database row-level security
restricts every snapshot to its signed-in athlete.
The first production-sized Android snapshot upload was validated on 25 August
2026. Raw activity samples remain local until the chunked transport is added;
their omission prevents oversized requests while retaining ride summaries.

Connected-service sync must preserve offline data when a provider is
unavailable. Temporary failures use bounded exponential retry, persist the next
attempt across app restarts and expose last-success and retry status in Connect.
The athlete can retry immediately without waiting for the automatic schedule.
Today remains focused on coaching, readiness, weather and the day's activity
rather than duplicating connection-management status.

App upgrades must migrate the existing on-device database in place. Athlete
profile, ride history and previously supported settings must survive schema
changes; newly introduced preferences receive safe defaults.

The application should feel like messaging a real coach.

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
