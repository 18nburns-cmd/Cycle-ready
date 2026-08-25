import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';

abstract interface class AthleteLearningRepository {
  Future<WorkoutResponseSnapshot?> getResponse(String workoutType);
  Stream<WorkoutResponseSnapshot?> watchResponse(String workoutType);
  Future<void> saveResponse(
    String workoutType,
    WorkoutResponseSnapshot response,
  );
  Future<bool> hasUnprocessedDecision(DateTime day);
  Future<void> markDecisionsProcessed(DateTime day);
}
