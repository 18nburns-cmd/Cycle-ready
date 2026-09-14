class AppRelease {
  const AppRelease({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri downloadUrl;

  bool get updateAvailable =>
      compareVersions(latestVersion, currentVersion) > 0;
}

int compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[.+-]'))
      .take(3)
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
  final a = parts(left);
  final b = parts(right);
  for (var index = 0; index < 3; index++) {
    final comparison = (index < a.length ? a[index] : 0)
        .compareTo(index < b.length ? b[index] : 0);
    if (comparison != 0) return comparison;
  }
  return 0;
}

abstract interface class AppReleaseRepository {
  Future<AppRelease> check();
}
