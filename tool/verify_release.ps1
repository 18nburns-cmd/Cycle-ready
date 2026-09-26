param(
  [string]$CloudDefinesPath = 'config/cloud_defines.json',
  [switch]$InstallOnPhone,
  [switch]$SkipMigrationStatus
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Invoke-Checked {
  param([string]$Program, [string[]]$Arguments)
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Program failed with exit code $LASTEXITCODE"
  }
}

$cloudDefines = Join-Path $repoRoot $CloudDefinesPath
if (-not (Test-Path -LiteralPath $cloudDefines -PathType Leaf)) {
  throw "Cloud defines file not found: $cloudDefines"
}
$keyProperties = Join-Path $repoRoot 'android/key.properties'
if (-not (Test-Path -LiteralPath $keyProperties -PathType Leaf)) {
  throw 'android/key.properties is required for a signed private release.'
}

Invoke-Checked flutter @('pub', 'get')
Invoke-Checked dart @('run', 'build_runner', 'build', '--delete-conflicting-outputs')
Invoke-Checked flutter @('test')
Invoke-Checked flutter @('analyze')
Invoke-Checked flutter @(
  'build', 'web', '--release', '--target', 'lib/main_web.dart',
  '--base-href', '/Cycle-ready/', "--dart-define-from-file=$cloudDefines"
)
Invoke-Checked dart @(
  'run', 'tool/verify_release_privacy.dart', 'build/web'
)
Invoke-Checked flutter @(
  'build', 'apk', '--release', '--target-platform', 'android-arm64',
  "--dart-define-from-file=$cloudDefines"
)

$apk = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) {
  throw "Release APK was not produced: $apk"
}
$privacyRoot = Join-Path $repoRoot 'build/release-privacy-apk'
$resolvedBuild = [IO.Path]::GetFullPath((Join-Path $repoRoot 'build'))
$resolvedPrivacy = [IO.Path]::GetFullPath($privacyRoot)
if (-not $resolvedPrivacy.StartsWith($resolvedBuild, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Refusing to prepare an APK scan outside the build directory.'
}
if (Test-Path -LiteralPath $resolvedPrivacy) {
  Remove-Item -LiteralPath $resolvedPrivacy -Recurse -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($apk, $resolvedPrivacy)
Invoke-Checked dart @(
  'run', 'tool/verify_release_privacy.dart', $resolvedPrivacy
)

if (-not $SkipMigrationStatus) {
  Invoke-Checked supabase @('migration', 'list')
}

if ($InstallOnPhone) {
  $localProperties = Join-Path $repoRoot 'android/local.properties'
  $sdkLine = Get-Content -LiteralPath $localProperties |
    Where-Object { $_ -like 'sdk.dir=*' } |
    Select-Object -First 1
  if (-not $sdkLine) { throw 'Android SDK path is missing from local.properties.' }
  $sdkPath = $sdkLine.Substring('sdk.dir='.Length).Replace('\\', '\')
  $adb = Join-Path $sdkPath 'platform-tools/adb.exe'
  if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    throw "ADB not found: $adb"
  }
  $devices = & $adb devices | Select-String "`tdevice$"
  if ($devices.Count -ne 1) {
    throw "Connect and unlock exactly one Android device; found $($devices.Count)."
  }
  Invoke-Checked $adb @('install', '-r', $apk)
  Invoke-Checked $adb @(
    'shell', 'monkey', '-p', 'com.cycleready.app', '-c',
    'android.intent.category.LAUNCHER', '1'
  )
}

Write-Host 'CycleReady release verification completed successfully.'
