# CycleReady Release Checklist

Use this checklist for every private Android or web release. Run it from a
clean working tree on the intended release commit. Do not paste secrets or
athlete records into the verification record.

## 1. Prepare

- Confirm the version and build number in `pubspec.yaml` are greater than the
  installed private release.
- Confirm the latest phone backup is readable and cloud synchronization has no
  unexplained pending or failed records.
- Confirm `config/cloud_defines.json`, Firebase configuration and Android
  signing files exist locally and remain ignored by Git.
- Review `git status` and the commit diff; exclude APKs, databases, exports,
  screenshots and diagnostic logs.

## 2. Run the reproducible gate

From PowerShell:

```powershell
pwsh -File tool/verify_release.ps1
```

The command restores dependencies, regenerates Drift sources, runs every test,
runs static analysis, builds release web and Android artifacts, privacy-scans
the web bundle and decompressed APK, and prints linked Supabase migration
status. Any failed command stops the release.

Migration status must show every local migration on the linked production
project. If the CLI is deliberately unavailable, use
`-SkipMigrationStatus`, record why, and verify status on a trusted machine
before publishing. Follow `docs/MIGRATION_RECOVERY.md` for failures.

## 3. Validate artifacts

- Open the locally built web dashboard and check authenticated Today,
  Performance, Calendar, Wellness and Nutrition at desktop and compact widths.
- Confirm the release APK is signed by the existing CycleReady key. A different
  signing key cannot update an installed copy.
- Confirm the privacy scan passed with any private canary values supplied via
  `CYCLEREADY_PRIVATE_SCAN_VALUES`.
- Record APK SHA-256 and expected Git commit without recording configuration
  values.

## 4. Install without losing data

Connect and unlock exactly one phone, then run:

```powershell
pwsh -File tool/verify_release.ps1 -InstallOnPhone
```

The script uses `adb install -r`; it never uninstalls or clears the app. After
launch, verify the signed-in account, latest ride, health data, event, current
plan and Today recommendation are unchanged. Confirm Today and Calendar show
the same workout and check Intervals.icu has only the current provider-owned
workout.

Never run the synthetic upgrade-smoke seed phase on a real phone. That test is
reserved for its disposable CI emulator.

## 5. Publish and observe

- Publish the APK and checksum only after all gates pass.
- Deploy web only from the same verified commit.
- Verify the private download link and perform one data-preserving update.
- Check the daily-coaching run, workout-delivery outbox, Intervals.icu calendar
  and notification delivery for the release account.
- Record the date, commit, test count, migration status, Android/web build
  results, phone model and smoke-test result in the release milestone.
