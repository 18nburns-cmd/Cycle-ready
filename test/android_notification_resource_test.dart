import 'dart:io';

import 'package:cycle_ready/src/features/health/data/health_connect_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  test('Android coaching notification icon is packaged', () {
    final service = File(
      'lib/src/features/coaching/application/coach_reminder_service.dart',
    ).readAsStringSync();
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_cycle_ready.xml',
    );
    final resourceKeep = File('android/app/src/main/res/raw/keep.xml');

    expect(
      service,
      contains("AndroidInitializationSettings('ic_stat_cycle_ready')"),
    );
    expect(icon.existsSync(), isTrue);
    expect(icon.readAsStringSync(), contains('<vector'));
    expect(resourceKeep.existsSync(), isTrue);
    expect(
      resourceKeep.readAsStringSync(),
      contains('tools:keep="@drawable/ic_stat_cycle_ready"'),
    );
  });

  test('Health Connect workout dependencies are declared', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/health/data/health_connect_repository.dart',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.health.READ_EXERCISE'));
    expect(manifest, contains('android.permission.health.READ_DISTANCE'));
    expect(
      manifest,
      contains('android.permission.health.READ_TOTAL_CALORIES_BURNED'),
    );
    expect(manifest, contains('android.permission.health.READ_STEPS'));
    expect(repository, contains('HealthDataType.DISTANCE_DELTA'));
    expect(repository, contains('HealthDataType.TOTAL_CALORIES_BURNED'));
    expect(repository, contains('HealthDataType.STEPS'));
    expect(repository, contains('healthConnectAuthorizationConfirmed'));
    expect(repository, contains("_permissionContractVersion = '2'"));
  });

  test('workout reads wait for associated Health Connect permissions', () {
    expect(
      HealthConnectRepository.safeReadableTypes(const [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.WORKOUT,
      ]),
      const [HealthDataType.SLEEP_SESSION],
    );
    expect(
      HealthConnectRepository.safeReadableTypes(const [
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.STEPS,
      ]),
      const [
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.STEPS,
      ],
    );
  });
}
