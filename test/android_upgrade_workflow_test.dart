import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android upgrade smoke reinstalls before verifying retained data', () {
    final workflow = File(
      '.github/workflows/android_upgrade_smoke.yml',
    ).readAsStringSync();
    final seed = workflow.indexOf('CYCLEREADY_UPGRADE_SMOKE_PHASE=seed');
    final verify = workflow.indexOf('CYCLEREADY_UPGRADE_SMOKE_PHASE=verify');

    expect(workflow, contains('android-emulator-runner@v2'));
    expect(seed, greaterThan(0));
    expect(verify, greaterThan(seed));
    expect(workflow, isNot(contains('adb uninstall')));
    expect(workflow, isNot(contains('pm clear')));
  });
}
