import 'package:cycle_ready/src/features/updates/domain/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic versions are compared numerically', () {
    expect(compareVersions('v1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('v2.0.0', '2.0.0'), 0);
    expect(compareVersions('1.0.9', '1.1.0'), lessThan(0));
  });

  test('release exposes whether an update is available', () {
    final release = AppRelease(
      currentVersion: '0.2.0',
      latestVersion: 'v0.3.0',
      downloadUrl: Uri.https('example.com', '/CycleReady.apk'),
    );
    expect(release.updateAvailable, isTrue);
  });
}
