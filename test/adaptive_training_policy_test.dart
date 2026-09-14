import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AdaptiveTrainingPolicy();

  test('calculates the policy weighted workout success score', () {
    const components = WorkoutSuccessComponents(
      completion: 100,
      targetAchievement: 80,
      physiologicalResponse: 70,
      subjectiveResponse: 60,
    );

    expect(components.score, 80);
  });

  test('keeps an appropriate workout and returns the required JSON contract',
      () {
    final result = policy.evaluate(_input());

    expect(result.athleteState, PolicyAthleteState.green);
    expect(result.decision, PolicyDecision.keep);
    expect(result.adaptationLevel, 0);
    expect(result.planChangeRequired, isFalse);
    expect(result.toJson(), containsPair('athlete_state', 'GREEN'));
    expect(result.toJson(), containsPair('decision', 'KEEP'));
    expect(result.toJson()['planned_workout'], isA<Map<String, Object?>>());
  });

  test('athlete symptoms override exceptional readiness', () {
    final result = policy.evaluate(_input(
      readiness: 96,
      illnessSymptoms: true,
    ));

    expect(result.athleteState, PolicyAthleteState.red);
    expect(result.decision, PolicyDecision.rest);
    expect(result.adaptedWorkout.intensity, PolicyWorkoutIntensity.rest);
    expect(result.reasonCodes, contains(PolicyReasonCode.illnessFlag));
  });

  test('one low readiness day makes only a session-level change', () {
    final result = policy.evaluate(_input(readiness: 42));

    expect(result.adaptationLevel, 1);
    expect(result.decision, PolicyDecision.changeToEndurance);
    expect(result.planChangeRequired, isFalse);
  });

  test('persistent poor recovery rebuilds the microcycle', () {
    final result = policy.evaluate(_input(
      readiness: 55,
      repeatedPoorRecoveryDays: 4,
    ));

    expect(result.adaptationLevel, 2);
    expect(result.decision, PolicyDecision.rebuildMicrocycle);
    expect(result.planChangeRequired, isTrue);
  });

  test('multi-week repeated failure rebuilds the block and reviews FTP', () {
    final result = policy.evaluate(_input(
      readiness: 70,
      similarFailedWorkouts: 3,
      ftpEvidenceCount: 3,
      estimatedFtpChangePercent: -5,
    ));

    expect(result.adaptationLevel, 3);
    expect(result.decision, PolicyDecision.rebuildBlock);
    expect(result.ftpReviewRequired, isTrue);
    expect(result.reasonCodes, contains(PolicyReasonCode.ftpDecreaseLikely));
  });

  test('low-confidence high readiness never causes progression', () {
    final result = policy.evaluate(_input(
      readiness: 92,
      hasRecentTrainingLoad: false,
      hasRecentWorkoutPerformance: false,
      strongSuccessfulWorkouts: 4,
      goodRecoveryDays: 4,
    ));

    expect(result.dataConfidence, PolicyDataConfidence.low);
    expect(result.decision, PolicyDecision.keep);
  });

  test('several strong sessions support one small progression', () {
    final result = policy.evaluate(_input(
      strongSuccessfulWorkouts: 3,
      goodRecoveryDays: 4,
    ));

    expect(result.decision, PolicyDecision.progress);
    expect(result.adaptedWorkout.targetLoad, closeTo(84, .001));
    expect(
        result.reasonCodes, contains(PolicyReasonCode.progressionAppropriate));
  });

  test('protects hard-session spacing and taper from added load', () {
    final hardSpacing = policy.evaluate(_input(consecutiveHardDays: 1));
    final taper = policy.evaluate(_input(
      readiness: 92,
      strongSuccessfulWorkouts: 4,
      goodRecoveryDays: 4,
      isTaper: true,
      daysUntilPriorityEvent: 7,
      fitnessAppropriateForEvent: true,
    ));

    expect(hardSpacing.decision, PolicyDecision.changeToEndurance);
    expect(taper.athleteState, PolicyAthleteState.peaking);
    expect(taper.decision, PolicyDecision.keep);
    expect(taper.reasonCodes, contains(PolicyReasonCode.taperProtection));
  });

  test('availability shortens volume without creating training debt', () {
    final result = policy.evaluate(_input(availableMinutes: 45));

    expect(result.decision, PolicyDecision.reduceVolume);
    expect(result.adaptedWorkout.durationMinutes, 45);
    expect(result.next72hEffect, contains('do not repay'));
  });
}

AdaptiveTrainingPolicyInput _input({
  int readiness = 78,
  bool illnessSymptoms = false,
  bool hasRecentTrainingLoad = true,
  bool hasRecentWorkoutPerformance = true,
  int repeatedPoorRecoveryDays = 0,
  int similarFailedWorkouts = 0,
  int strongSuccessfulWorkouts = 0,
  int goodRecoveryDays = 0,
  int consecutiveHardDays = 0,
  int ftpEvidenceCount = 0,
  double estimatedFtpChangePercent = 0,
  bool isTaper = false,
  int? daysUntilPriorityEvent,
  bool fitnessAppropriateForEvent = false,
  int? availableMinutes,
}) =>
    AdaptiveTrainingPolicyInput(
      plannedWorkout: const PolicyWorkout(
        id: 'threshold-1',
        title: 'Threshold 4 × 8 min',
        intensity: PolicyWorkoutIntensity.high,
        durationMinutes: 70,
        targetLoad: 80,
        intervalRepetitions: 4,
      ),
      readiness: readiness,
      fatigueRisk: 25,
      trainingProgress: 70,
      goalAlignment: 90,
      hasRecentTrainingLoad: hasRecentTrainingLoad,
      hasRecentWorkoutPerformance: hasRecentWorkoutPerformance,
      illnessSymptoms: illnessSymptoms,
      repeatedPoorRecoveryDays: repeatedPoorRecoveryDays,
      similarFailedWorkouts: similarFailedWorkouts,
      strongSuccessfulWorkouts: strongSuccessfulWorkouts,
      goodRecoveryDays: goodRecoveryDays,
      consecutiveHardDays: consecutiveHardDays,
      ftpEvidenceCount: ftpEvidenceCount,
      estimatedFtpChangePercent: estimatedFtpChangePercent,
      isTaper: isTaper,
      daysUntilPriorityEvent: daysUntilPriorityEvent,
      fitnessAppropriateForEvent: fitnessAppropriateForEvent,
      availableMinutes: availableMinutes,
    );
