import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release verifier covers every mandatory gate in safe order', () {
    final script = File('tool/verify_release.ps1').readAsStringSync();
    final tests = script.indexOf("@('test')");
    final analysis = script.indexOf("@('analyze')");
    final web = script.indexOf("'build', 'web'");
    final android = script.indexOf("'build', 'apk'");
    final migration = script.indexOf("@('migration', 'list')");
    final install = script.indexOf("@('install', '-r', \$apk)");

    expect(tests, greaterThan(0));
    expect(analysis, greaterThan(tests));
    expect(web, greaterThan(analysis));
    expect(android, greaterThan(web));
    expect(migration, greaterThan(android));
    expect(install, greaterThan(migration));
    expect(script, contains('verify_release_privacy.dart'));
    expect(script, isNot(contains("'uninstall'")));
    expect(script, isNot(contains("'pm', 'clear'")));
  });

  test('release checklist includes build, migration and phone verification',
      () {
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();
    for (final item in const [
      'runs every test',
      'static analysis',
      'release web and Android artifacts',
      'Supabase migration',
      'adb install -r',
      'Confirm Today and Calendar show',
      'test count',
    ]) {
      expect(checklist, contains(item), reason: item);
    }
  });
}
