import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_release_privacy.dart';

void main() {
  late Directory temporary;

  setUp(() => temporary = Directory.systemTemp.createTempSync('privacy-scan-'));
  tearDown(() => temporary.deleteSync(recursive: true));

  test('clean release content passes', () async {
    File('${temporary.path}/manifest.json')
        .writeAsStringSync('{"version":"0.2.5"}');

    expect(await scanReleasePrivacy([temporary]), isEmpty);
  });

  test('secret signatures and configured private values fail safely', () async {
    File('${temporary.path}/secret.txt')
        .writeAsStringSync('INTERVALS_CLIENT_SECRET=not-for-release');
    File('${temporary.path}/bundle.bin')
        .writeAsBytesSync('prefix-athlete-private-token-suffix'.codeUnits);

    final findings = await scanReleasePrivacy(
      [temporary],
      deniedValues: const ['athlete-private-token'],
    );

    expect(findings, hasLength(2));
    expect(findings.map((item) => item.reason),
        everyElement(isNot(contains('not-for-release'))));
    expect(findings.map((item) => item.reason),
        everyElement(isNot(contains('athlete-private-token'))));
  });

  test('private athlete data file types cannot enter an artifact', () async {
    File('${temporary.path}/athlete.sqlite').writeAsBytesSync([1, 2, 3]);
    File('${temporary.path}/ride.fit').writeAsBytesSync([4, 5, 6]);

    final findings = await scanReleasePrivacy([temporary]);

    expect(findings, hasLength(2));
    expect(findings.map((item) => item.reason),
        everyElement(contains('not release-safe')));
  });

  test('release workflows scan web and decompressed Android artifacts', () {
    final web = File('.github/workflows/deploy_web.yml').readAsStringSync();
    final android =
        File('.github/workflows/release_android.yml').readAsStringSync();

    expect(web, contains('verify_release_privacy.dart build/web'));
    expect(android, contains('unzip -q'));
    expect(android, contains('verify_release_privacy.dart build/privacy-apk'));
    expect(web, isNot(contains('set -x')));
    expect(android, isNot(contains('set -x')));
  });
}
