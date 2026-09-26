import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:cycle_ready/src/features/activities/domain/session_outcome_policy.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'imported ride drives analysis, learning, next-day adaptation and delivery',
      () async {
    // This summary and trace represent the normalized result of a provider
    // import. Every later stage uses production domain code.
    final ride = analyseRide(
      durationSeconds: 70 * 60,
      distanceMetres: 36000,
      ftp: 250,
      maximumHeartRate: 190,
      weightKg: 72,
      averagePower: 215,
      averageHeartRate: 158,
      normalisedPower: 240,
      samples: const [
        (elapsedSeconds: 0, power: 150, heartRate: 120),
        (elapsedSeconds: 600, power: 245, heartRate: 165),
        (elapsedSeconds: 1800, power: 250, heartRate: 170),
        (elapsedSeconds: 3300, power: 220, heartRate: 168),
      ],
    );
    expect(ride.intensityFactor, closeTo(.96, .001));
    expect(ride.workKilojoules, closeTo(903, .1));

    final outcome = const SessionOutcomePolicy().evaluate(
      purpose: const SessionPurpose(
        sessionType: CoachingSessionType.threshold,
        primaryAdaptation: 'Sustainable threshold power',
        secondaryAdaptation: 'Fatigue resistance',
        plannedDurationMinutes: 70,
        targetIntensity: '95-100% FTP',
        keyIntervals: ['4 x 8 min'],
        successMetrics: ['Complete every interval in range'],
        progressionIfSuccessful: 'Progress one variable after absorption.',
        actionIfUnsuccessful: 'Hold or reduce the smallest variable.',
      ),
      evidence: SessionOutcomeEvidence(
        completedDurationMinutes: 70,
        intervalCompletionPercent: 100,
        powerTargetAchievementPercent: ride.intensityFactor! * 100,
        intervalQualityPercent: 92,
        timeInTargetPercent: 88,
        rpe: 8,
        expectedRpe: 7,
        nextDayHrvChangePercent: -12,
        nextDayRestingHrDelta: 7,
        soreness: 4,
        fatigue: 5,
        readinessDrop: 25,
        recoveryWasNormal: false,
      ),
    );
    expect(outcome.adaptationAchieved, isTrue);
    expect(outcome.sessionOutcome, SessionOutcome.achievedHighCost);
    expect(outcome.nextSessionAction, NextSessionAction.changeToRecovery);

    final compliance = assessWorkoutCompliance(
      plannedLoad: 75,
      plannedMinutes: 70,
      actualLoad: 96,
      actualMinutes: 70,
    );
    final learned = updateWorkoutResponse(
      previous: const WorkoutResponseSnapshot(
        sampleCount: 3,
        averageLoadRatio: 1.22,
        averageDurationRatio: 1,
        completionRate: 1,
        feedbackSamples: 3,
        averagePerceivedEffort: 8,
        averageLegFatigue: 4,
      ),
      compliance: compliance,
      perceivedEffort: 8,
      legFatigue: 5,
    );
    final learnedAdjustment = personaliseWorkout(learned);
    expect(learned.sampleCount, 4);
    expect(learnedAdjustment.loadMultiplier, lessThan(1));

    final nextDay = const AdaptiveTrainingPolicy().evaluate(
      AdaptiveTrainingPolicyInput(
        plannedWorkout: const PolicyWorkout(
          id: 'threshold-next-day',
          title: 'Threshold · 4 × 8 min',
          intensity: PolicyWorkoutIntensity.high,
          durationMinutes: 70,
          targetLoad: 78,
          intervalRepetitions: 4,
        ),
        readiness: 44,
        fatigueRisk: outcome.recoveryCostScore,
        trainingProgress: outcome.stimulusAchievementScore,
        goalAlignment: 85,
        hasRecentWorkoutPerformance: true,
        hasRecentSleep: true,
        hasRecentHrv: true,
        hasRecentRestingHeartRate: true,
        hrvChangePercent: -12,
        restingHeartRateDelta: 7,
        fatigue: 5,
        soreness: 4,
        workoutSuccessScore: outcome.stimulusAchievementScore.toDouble(),
      ),
    );
    expect(
        nextDay.adaptedWorkout.intensity, isNot(PolicyWorkoutIntensity.high));

    final context = WorkoutGenerationContext(
      id: nextDay.adaptedWorkout.id,
      day: DateTime(2026, 9, 22),
      durationMinutes: nextDay.adaptedWorkout.durationMinutes,
      targetLoad: nextDay.adaptedWorkout.targetLoad.round(),
      reason: nextDay.explanation,
      confidence: nextDay.confidence,
      learnedAdjustment: learnedAdjustment,
    );
    final generated = switch (nextDay.adaptedWorkout.intensity) {
      PolicyWorkoutIntensity.rest ||
      PolicyWorkoutIntensity.recovery =>
        const WorkoutGenerator().recovery(context),
      PolicyWorkoutIntensity.endurance =>
        const WorkoutGenerator().endurance(context),
      PolicyWorkoutIntensity.moderate =>
        const WorkoutGenerator().tempo(context),
      PolicyWorkoutIntensity.high =>
        const WorkoutGenerator().threshold(context),
    };
    expect(const WorkoutValidator().validate(generated).isValid, isTrue);
    expect(generated.purpose, isNot(WorkoutPurpose.threshold));

    final provider = MockWorkoutDeliveryProvider();
    final delivery = await provider.deliver([generated]);
    expect(delivery.provider, provider.id);
    expect(delivery.delivered, 1);
    expect(provider.deliveredWorkouts.single.id, 'threshold-next-day');
    expect(provider.deliveredWorkouts.single.purpose, generated.purpose);
  });
}
