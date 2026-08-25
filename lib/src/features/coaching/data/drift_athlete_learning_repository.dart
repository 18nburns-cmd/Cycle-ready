import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriftAthleteLearningRepository implements AthleteLearningRepository {
  const DriftAthleteLearningRepository(this.database);

  final AppDatabase database;

  @override
  Future<WorkoutResponseSnapshot?> getResponse(String workoutType) async =>
      _toDomain(await database.workoutResponseProfile(workoutType));

  @override
  Stream<WorkoutResponseSnapshot?> watchResponse(String workoutType) =>
      database.watchWorkoutResponseProfile(workoutType).map(_toDomain);

  @override
  Future<void> saveResponse(
    String workoutType,
    WorkoutResponseSnapshot response,
  ) =>
      database.saveWorkoutResponseProfile(
        WorkoutResponseProfilesCompanion.insert(
          workoutType: workoutType,
          sampleCount: Value(response.sampleCount),
          averageLoadRatio: Value(response.averageLoadRatio),
          averageDurationRatio: Value(response.averageDurationRatio),
          completionRate: Value(response.completionRate),
          feedbackSamples: Value(response.feedbackSamples),
          averagePerceivedEffort: Value(response.averagePerceivedEffort),
          averageLegFatigue: Value(response.averageLegFatigue),
          updatedAt: DateTime.now(),
        ),
      );

  @override
  Future<bool> hasUnprocessedDecision(DateTime day) =>
      database.hasUnprocessedCoachingDecision(day);

  @override
  Future<void> markDecisionsProcessed(DateTime day) =>
      database.markCoachingDecisionsProcessed(day);

  WorkoutResponseSnapshot? _toDomain(WorkoutResponseProfile? row) => row == null
      ? null
      : WorkoutResponseSnapshot(
          sampleCount: row.sampleCount,
          averageLoadRatio: row.averageLoadRatio,
          averageDurationRatio: row.averageDurationRatio,
          completionRate: row.completionRate,
          feedbackSamples: row.feedbackSamples,
          averagePerceivedEffort: row.averagePerceivedEffort,
          averageLegFatigue: row.averageLegFatigue,
        );
}

final athleteLearningRepositoryProvider = Provider<AthleteLearningRepository>(
  (ref) => DriftAthleteLearningRepository(ref.watch(databaseProvider)),
);
