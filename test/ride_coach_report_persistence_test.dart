import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/application/post_ride_feedback_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('ride coach report persists planned comparison and tomorrow advice',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertRide(database);

    await database.saveRideCoachReport(
      RideCoachReportsCompanion.insert(
        activityId: 'ride-1',
        createdAt: DateTime(2026, 8, 25, 20),
        plannedTitle: const Value('Tempo 3 x 12 min'),
        executionScore: 8.4,
        objective: 'Tempo - achieved',
        summary: 'You delivered the planned tempo stimulus.',
        execution: 'You completed 98% of planned load.',
        tomorrowRecommendation: 'Easy endurance',
        keyFocus: 'Keep the opening effort controlled.',
        confidence: 'high',
        confidenceReason: 'Power, heart rate and history were available.',
      ),
    );

    final report = await database.watchRideCoachReport('ride-1').first;
    expect(report?.plannedTitle, 'Tempo 3 x 12 min');
    expect(report?.executionScore, 8.4);
    expect(report?.tomorrowRecommendation, 'Easy endurance');
    expect(report?.confidence, 'high');
  });

  test('ride coach reports survive backup restore and are erased with data',
      () async {
    final source = AppDatabase(NativeDatabase.memory());
    await _insertRide(source);
    await source.saveRideCoachReport(
      RideCoachReportsCompanion.insert(
        activityId: 'ride-1',
        createdAt: DateTime(2026, 8, 25, 20),
        executionScore: 7.5,
        objective: 'Endurance - achieved',
        summary: 'A controlled endurance ride.',
        execution: 'Duration and load were on target.',
        tomorrowRecommendation: 'Normal training',
        keyFocus: 'Recover and refuel.',
        confidence: 'medium',
        confidenceReason: 'Three key signals were available.',
      ),
    );

    final snapshot = await source.exportSnapshot();
    await source.close();
    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await restored.restoreSnapshot(snapshot);
    expect(await restored.watchRideCoachReport('ride-1').first, isNotNull);

    await restored.eraseAllUserData();
    expect(await restored.watchRideCoachReport('ride-1').first, isNull);
  });

  test('saving feedback automatically creates the persisted coach report',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await _insertRide(database);
    await database.savePlannedSession(
      PlannedSessionsCompanion.insert(
        day: DateTime(2026, 8, 25),
        sessionType: 'tempo',
        title: 'Tempo 3 x 12 min',
        durationMinutes: 60,
        targetLoad: 60,
      ),
    );

    await container.read(postRideFeedbackControllerProvider).save(
          activityId: 'ride-1',
          perceivedEffort: 7,
          legFatigue: 5,
          enjoyment: 8,
          discomfort: 0,
          notes: 'Controlled session',
        );

    final report = await database.watchRideCoachReport('ride-1').first;
    expect(report, isNotNull);
    expect(report?.plannedTitle, 'Tempo 3 x 12 min');
    expect(report?.execution, contains('planned duration'));
    expect(report?.tomorrowRecommendation, isNotEmpty);
  });
}

Future<void> _insertRide(AppDatabase database) =>
    database.into(database.activities).insert(
          ActivitiesCompanion.insert(
            id: 'ride-1',
            source: 'test',
            startedAt: DateTime(2026, 8, 25, 10),
            durationSeconds: 3600,
            distanceMetres: 30000,
          ),
        );
