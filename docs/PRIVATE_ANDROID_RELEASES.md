# Private Android releases

CycleReady is distributed directly as a signed APK and is not published to an
app store. Every phone must install releases signed by the same private key;
losing that key requires uninstalling the app and therefore risks local data.

## One-time GitHub configuration

Create a dedicated release keystore and keep an offline backup. Add these
GitHub Actions secrets:

- `CYCLEREADY_ANDROID_KEYSTORE_BASE64`
- `CYCLEREADY_ANDROID_STORE_PASSWORD`
- `CYCLEREADY_ANDROID_KEY_ALIAS`
- `CYCLEREADY_ANDROID_KEY_PASSWORD`
- `CYCLEREADY_FIREBASE_JSON_BASE64`
- `CYCLEREADY_SUPABASE_PUBLISHABLE_KEY`

Keep `CYCLEREADY_SUPABASE_URL` as a repository variable. Never commit the
keystore, passwords, Firebase file or generated cloud configuration.

## Publishing

Increase `version` in `pubspec.yaml`, create a matching tag such as `v0.2.0`,
and push the tag. The Android release workflow regenerates Drift database
sources on its clean Linux runner, runs tests and analysis, builds
the arm64 APK, signs it, creates a SHA-256 checksum and attaches both files to
the GitHub release. It can also be started manually from GitHub Actions.

Run the gates in `docs/RELEASE_CHECKLIST.md` before tagging. The workflow
decompresses the APK and rejects embedded private keys, server secrets, local
databases, ride exports and logs before publishing. The separate Android
upgrade smoke workflow verifies replacement-install data preservation on a
disposable emulator; never run its seed phase on an athlete's phone.

## Installing and updating

On the phone, allow the browser to install unknown apps, download the APK from
the trusted CycleReady release, and open it. Choose **Update** when Android
recognises the existing signature. Never uninstall first: installing over the
existing app preserves local data. Connect shows **Download update** whenever
GitHub contains a newer semantic version.

Before sharing a release, compare its SHA-256 digest with the `.sha256` file.
Only distribute the direct release link to intended CycleReady users.

Record verified test counts, production validation dates and any incomplete
gate in `docs/RELEASE_MILESTONES.md`.
