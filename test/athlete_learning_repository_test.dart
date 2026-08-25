import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_athlete_learning_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftAthleteLearningRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftAthleteLearningRepository(database);
  });

  tearDown(() => database.close());

  test('stores and watches a domain workout-response snapshot', () async {
    const response = WorkoutResponseSnapshot(
      sampleCount: 4,
      averageLoadRatio: .96,
      averageDurationRatio: .92,
      completionRate: .75,
      feedbackSamples: 3,
      averagePerceivedEffort: 7.3,
      averageLegFatigue: 2.7,
    );
    await repository.saveResponse('intervals', response);

    final stored = await repository.watchResponse('intervals').first;
    expect(stored?.sampleCount, 4);
    expect(stored?.averageLoadRatio, .96);
    expect(stored?.completionRate, .75);
    expect(stored?.coachingInsight, contains('absorb and complete'));
  });

  test('tracks whether a coaching decision has been processed', () async {
    final day = DateTime(2026, 8, 26);
    await database.saveCoachingDecision(
      CoachingDecisionsCompanion.insert(
        createdAt: day,
        scheduledDay: day,
        workoutType: 'tempo',
        title: 'Tempo 3 x 12 min',
        reason: 'Progress sustained power.',
        readiness: 74,
        fitness: 52,
        fatigue: 48,
        form: 4,
        targetLoad: 78,
        confidence: const Value(.82),
      ),
    );

    expect(await repository.hasUnprocessedDecision(day), isTrue);
    await repository.markDecisionsProcessed(day);
    expect(await repository.hasUnprocessedDecision(day), isFalse);
  });
}
