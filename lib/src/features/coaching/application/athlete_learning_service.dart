import 'package:cycle_ready/src/features/coaching/data/drift_athlete_learning_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final athleteLearningServiceProvider = Provider(AthleteLearningService.new);

final workoutResponseProfileProvider =
    StreamProvider.family<WorkoutResponseSnapshot?, String>(
  (ref, type) =>
      ref.watch(athleteLearningRepositoryProvider).watchResponse(type),
);

class AthleteLearningService {
  const AthleteLearningService(this.ref);
  final Ref ref;

  Future<bool> learnFromCompletedSession({
    required DateTime day,
    required String workoutType,
    required WorkoutCompliance compliance,
    int? perceivedEffort,
    int? legFatigue,
  }) async {
    final repository = ref.read(athleteLearningRepositoryProvider);
    if (!await repository.hasUnprocessedDecision(day)) return false;
    final previous = await repository.getResponse(workoutType) ??
        const WorkoutResponseSnapshot();
    final learned = updateWorkoutResponse(
      previous: previous,
      compliance: compliance,
      perceivedEffort: perceivedEffort,
      legFatigue: legFatigue,
    );
    await repository.saveResponse(workoutType, learned);
    await repository.markDecisionsProcessed(day);
    return true;
  }
}
