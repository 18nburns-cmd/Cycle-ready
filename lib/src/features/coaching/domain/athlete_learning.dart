import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';

class WorkoutResponseSnapshot {
  const WorkoutResponseSnapshot({
    this.sampleCount = 0,
    this.averageLoadRatio = 1,
    this.averageDurationRatio = 1,
    this.completionRate = 0,
    this.feedbackSamples = 0,
    this.averagePerceivedEffort = 0,
    this.averageLegFatigue = 0,
  });

  final int sampleCount;
  final double averageLoadRatio;
  final double averageDurationRatio;
  final double completionRate;
  final int feedbackSamples;
  final double averagePerceivedEffort;
  final double averageLegFatigue;

  String get coachingInsight {
    if (sampleCount < 3) {
      return 'CycleReady is establishing your response to this workout type.';
    }
    if (completionRate < .7) {
      return 'You complete this workout type less consistently than your other training. The dose or placement may need adjusting.';
    }
    if (averageLoadRatio > 1.2 || averageLegFatigue >= 4) {
      return 'This workout type usually costs you more than planned, so extra recovery protection is appropriate afterwards.';
    }
    if (averageLoadRatio < .75 || averageDurationRatio < .75) {
      return 'This workout type is often completed below target. CycleReady should favour a more achievable structure rather than forcing extra load.';
    }
    return 'You generally absorb and complete this workout type as planned.';
  }
}

WorkoutResponseSnapshot updateWorkoutResponse({
  required WorkoutResponseSnapshot previous,
  required WorkoutCompliance compliance,
  int? perceivedEffort,
  int? legFatigue,
}) {
  final nextSamples = previous.sampleCount + 1;
  double average(double current, double value, int oldCount) =>
      (current * oldCount + value) / (oldCount + 1);
  final completed =
      compliance.outcome == PlannedWorkoutOutcome.missed ? 0.0 : 1.0;
  final hasFeedback = perceivedEffort != null || legFatigue != null;
  final nextFeedbackSamples = previous.feedbackSamples + (hasFeedback ? 1 : 0);
  return WorkoutResponseSnapshot(
    sampleCount: nextSamples,
    averageLoadRatio: average(
      previous.averageLoadRatio,
      compliance.loadRatio,
      previous.sampleCount,
    ),
    averageDurationRatio: average(
      previous.averageDurationRatio,
      compliance.durationRatio,
      previous.sampleCount,
    ),
    completionRate: average(
      previous.completionRate,
      completed,
      previous.sampleCount,
    ),
    feedbackSamples: nextFeedbackSamples,
    averagePerceivedEffort: perceivedEffort == null
        ? previous.averagePerceivedEffort
        : average(
            previous.averagePerceivedEffort,
            perceivedEffort.toDouble(),
            previous.feedbackSamples,
          ),
    averageLegFatigue: legFatigue == null
        ? previous.averageLegFatigue
        : average(
            previous.averageLegFatigue,
            legFatigue.toDouble(),
            previous.feedbackSamples,
          ),
  );
}
