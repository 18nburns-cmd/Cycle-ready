# CycleReady

## Web dashboard

CycleReady includes a responsive web-dashboard entry point that intentionally
excludes Android-only health and hardware integrations:

```powershell
flutter run -d chrome -t lib/main_web.dart
flutter build web --release -t lib/main_web.dart
```

The generated release files are written to `build/web`. Personal athlete data
will remain unavailable in the browser until authenticated cloud sync is
configured.

Create a Supabase project, apply
`supabase/migrations/202608250001_create_athlete_snapshots.sql`, then supply only
its public client configuration at build time:

```powershell
flutter run -d chrome -t lib/main_web.dart `
  --dart-define=CYCLEREADY_SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=CYCLEREADY_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never use a Supabase secret or service-role key in either CycleReady client.

CycleReady is a private, Flutter-based Android cycling coach and wellness
monitor. It combines ride history, recovery, body composition, nutrition and
training availability to recommend what to do next and explain why.

## Current capabilities

- Explainable daily readiness, recovery time and morning check-in
- Intervals.icu activity, wellness and structured-workout integration
- Health Connect import where the Android device supports it
- FIT import with power, heart rate, cadence, GPS and elevation samples
- Persistent ride history, route maps and advanced ride analysis
- Fitness, fatigue, form, ramp rate and 14-day fitness forecasting
- Eight-week FTP estimation, critical power and power-curve development focus
- Adaptive four-week cycling plans built around availability and goal events
- More than 200 phase-aware workout combinations with percentage-of-FTP steps
- Automatic refresh of future adaptive workouts when FTP changes
- Recommendation confidence and athlete-specific decision evidence
- Planned-versus-completed ride reports with durable tomorrow recommendations
- Calories, macros, hydration, saved foods and nutrition-label scanning
- Weight/body-composition history, CSV import and experimental Bluetooth scales
- Strength and mobility programmes with guided exercise media and progression
- Offline, on-device coach with reminders and post-ride feedback learning
- Local backup, restore, export and complete-data deletion

CycleReady provides wellness and training guidance, not medical diagnosis.

## Technology

- Flutter and Dart
- Riverpod for dependency injection and state
- GoRouter for navigation
- Drift/SQLite for offline-first storage
- Intervals.icu REST integration
- Android Health Connect through the `health` package
- ML Kit text recognition for nutrition labels
- On-device local language-model support

Code is organised by feature with domain, application, data and presentation
boundaries. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the rules.

## Development setup

Install Flutter, Android Studio (including the Android SDK), and connect an
Android phone with USB debugging enabled. Then run:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test --concurrency=1
flutter run
```

The Android application ID is `com.cycleready.app`. The minimum Android SDK is
26. Generated Drift files must be refreshed after database schema changes.

## Updating a connected phone without losing data

Build and install over the existing application rather than uninstalling it:

```powershell
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Use CycleReady's backup screen before risky platform or database work. Never
put Intervals.icu credentials, API tokens or service secrets in source control.

## Project source of truth

- `AGENTS.md` - repository working rules
- `docs/PRODUCT_SPEC.md` - product behaviour and vision
- `docs/ARCHITECTURE.md` - module and dependency boundaries
- `docs/TODO.md` - ordered implementation tasks
- `docs/ROADMAP.md` - completed capabilities and future direction
