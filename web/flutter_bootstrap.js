{{flutter_js}}
{{flutter_build_config}}

// GitHub Pages may cache compiled assets for several minutes. Give the Dart
// entrypoint a unique request URL on every page load and deliberately avoid
// Flutter's deprecated service worker so a new CycleReady release is visible
// immediately.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?release=${Date.now()}`;
  }
}

_flutter.loader.load();
