import 'package:cycle_ready/src/core/database/app_database.dart' as db;
import 'package:cycle_ready/src/features/athlete/data/drift_athlete_profile_repository.dart';
import 'package:cycle_ready/src/features/athlete/data/drift_athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart'
    as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists the athlete state and profile through Drift', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAthleteRepository(
      database,
      DriftAthleteProfileRepository(database),
    );
    final expected = domain.AthleteState(
      profile: const AthleteProfile(
        name: 'Neil',
        experienceLevel: 'advanced',
        ftp: 255,
        maximumHeartRate: 188,
        restingHeartRate: 48,
        weightKg: 71.5,
        weeklyLoadTarget: 420,
      ),
      updatedAt: DateTime(2026, 8, 25),
      fitness: 72,
      fatigue: 31,
      freshness: 69,
      readiness: 84,
      recovery: 88,
      hrvTrend: 4.5,
      weightTrend: -0.3,
    );

    await repository.saveState(expected);
    final actual = await repository.getState();

    expect(actual.profile.name, 'Neil');
    expect(actual.profile.ftp, 255);
    expect(actual.readiness, expected.readiness);
    expect(actual.recovery, expected.recovery);
    expect(actual.hrvTrend, expected.hrvTrend);
    expect(actual.weightTrend, expected.weightTrend);

    final history = await repository.getHistory();
    expect(history, hasLength(1));
    expect(history.single.updatedAt, expected.updatedAt);
    expect(history.single.readiness, expected.readiness);
  });
}
