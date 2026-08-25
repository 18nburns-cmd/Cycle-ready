import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('export contains every data category and stored records', () async {
    await database.saveBodyMeasurement(
      BodyMeasurementsCompanion.insert(
        measuredAt: DateTime(2026, 7, 28),
        weightKg: 72.5,
        source: 'manual',
      ),
    );

    final export = await database.exportSnapshot();
    expect(export['schemaVersion'], 20);
    expect(
        export.keys,
        containsAll([
          'activities',
          'activitySamples',
          'athleteSettings',
          'dailyRecovery',
          'bodyMeasurements',
          'plannedSessions',
          'ftpEstimates',
          'trainingPreferences',
          'eventGoals',
          'nutritionEntries',
          'dailyNutritionTargets',
          'rideCoachReports',
        ]));
    expect(export['bodyMeasurements'], hasLength(1));
  });

  test('erase removes health and training records', () async {
    final day = DateTime(2026, 7, 28);
    await database.saveBodyMeasurement(
      BodyMeasurementsCompanion.insert(
        measuredAt: day,
        weightKg: 72.5,
        source: 'manual',
      ),
    );
    await database.saveRecovery(
      DailyRecoveryRecordsCompanion.insert(day: day),
    );
    await database.savePlannedSession(
      PlannedSessionsCompanion.insert(
        day: day,
        sessionType: 'endurance',
        title: 'Endurance',
        durationMinutes: 60,
        targetLoad: 40,
      ),
    );

    await database.eraseAllUserData();

    expect(await database.watchBodyMeasurements().first, isEmpty);
    expect(await database.recoveryForDay(day), isNull);
    expect(await database.getPlannedSessions(day, day), isEmpty);
  });

  test('export can restore records after local data is erased', () async {
    final day = DateTime(2026, 7, 28);
    await database.saveBodyMeasurement(
      BodyMeasurementsCompanion.insert(
        measuredAt: day,
        weightKg: 72.5,
        source: 'manual',
      ),
    );
    await database.savePlannedSession(
      PlannedSessionsCompanion.insert(
        day: day,
        sessionType: 'endurance',
        title: 'Steady ride',
        durationMinutes: 60,
        targetLoad: 45,
      ),
    );
    final snapshot = await database.exportSnapshot();
    await database.eraseAllUserData();

    await database.restoreSnapshot(snapshot);

    expect(await database.watchBodyMeasurements().first, hasLength(1));
    expect(await database.getPlannedSessions(day, day), hasLength(1));
  });

  test('invalid backup is rejected before existing data is changed', () async {
    await database.saveBodyMeasurement(
      BodyMeasurementsCompanion.insert(
        measuredAt: DateTime(2026, 7, 28),
        weightKg: 72.5,
        source: 'manual',
      ),
    );

    await expectLater(
      database.restoreSnapshot({
        'schemaVersion': database.schemaVersion,
        'activities': ['not a record'],
      }),
      throwsFormatException,
    );
    expect(await database.watchBodyMeasurements().first, hasLength(1));
  });
}
