# CycleReady delivery roadmap

Updated: 25 August 2026

## Delivered foundation

- Flutter Android shell, dark design system, navigation and splash experience
- Offline-first Drift database with backup, restore and privacy controls
- Athlete profile, body metrics, check-ins and explainable readiness
- Health Connect, FIT files and Intervals.icu data sources
- Ride history, maps, power/heart-rate analysis and post-ride feedback
- Fitness, fatigue, form, ramp rate, forecasting, FTP and critical power
- Training calendar, availability, events and phase-aware adaptive planning
- Percentage-of-FTP structured workouts and Intervals.icu delivery
- Nutrition, hydration, food label scanning and reusable foods
- Strength and mobility programming with session history
- Offline coaching, local notifications and athlete-response learning

## Current coaching milestone

CycleReady now has a unified daily coaching context containing athlete profile,
readiness, recent rides, load, availability, goal phase and learned workout
response. Daily recommendations expose confidence and evidence. Post-ride
reports compare completed work with the plan and persist tomorrow's advice.

The next milestone is calibration: use accumulated real-world results to improve
confidence, workout progression and recovery decisions while keeping all safety
rules deterministic and testable.

## Near-term priorities

1. Expand the athlete profile with equipment, injury history, ride-time and
   nutrition preferences.
2. Continue moving legacy database access behind feature repositories; planned
   sessions, training preferences, goal events and body measurements now have
   repository seams, as does learned workout response and decision processing.
3. Extend the delivered preferred-time weather cache and stale-data safeguards
   with an optional multi-day outdoor-planning preview.
4. Extend the delivered interval-step execution comparison with automatic
   start-offset detection for outdoor recordings that include extra riding
   before the prescribed warm-up.
5. Add seasonal wellness and performance review views.
6. Extend the delivered restart-safe sync retry and visible status with native
   Android background execution when its battery and maintenance trade-offs are
   validated on target devices.
7. Extend the delivered schema 17 and 19 SQLite migration fixtures whenever a
   future database version is released.

## External integrations

- Intervals.icu remains the primary activity and workout service.
- Health Connect is optional because device support varies.
- RENPHO data should arrive through a supported health provider where possible.
- Garmin direct integration requires approved Garmin developer access.
- Strava direct integration requires a backend for OAuth secrets and webhooks;
  no client secret should ever ship in the APK.

## Longer-term research

- Automatic illness and overreaching detection
- Voice and live ride coaching
- Indoor trainer control
- Race pacing and fuelling strategy
- Wear OS companion experience
- Computer-vision bike-fit assistance

These items remain research until their data requirements, safety boundaries and
maintenance cost are understood. `docs/TODO.md` is the authoritative execution
order for active work.
