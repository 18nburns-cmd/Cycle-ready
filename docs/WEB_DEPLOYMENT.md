# CycleReady web deployment

The responsive web dashboard is deployed from `main` by
`.github/workflows/deploy_web.yml`. GitHub Actions builds the browser-specific
entry point and publishes `build/web` to GitHub Pages.

## Repository configuration

In GitHub, open **Settings > Secrets and variables > Actions** and configure:

- Repository variable `CYCLEREADY_SUPABASE_URL`
- Repository secret `CYCLEREADY_SUPABASE_PUBLISHABLE_KEY`

The publishable Supabase key is intended for client applications, but storing
it as an Actions secret avoids duplicating environment configuration in source
control. Row-level security remains the actual data-access boundary.

Under **Settings > Pages**, set **Source** to **GitHub Actions**. A push to
`main`, or a manual run from the Actions page, then deploys the dashboard to:

`https://18nburns-cmd.github.io/Cycle-ready/`

Add that exact URL to the Supabase Authentication site URL and redirect URL
allow-list before validating sign-in. The Android application and website must
use the same CycleReady account to access the same athlete snapshot.

## Local release build

Local configuration remains in ignored `config/cloud_defines.json`:

```powershell
flutter build web --release -t lib/main_web.dart --base-href /Cycle-ready/ --dart-define-from-file=config/cloud_defines.json
```

Never commit service-role keys, account passwords, Intervals.icu credentials,
or private athlete exports.
