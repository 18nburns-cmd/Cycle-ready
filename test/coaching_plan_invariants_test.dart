import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/strategic_training_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('illness and low recovery can never preserve unsafe intensity', () {
    const planned = PolicyWorkout(
      id: 'high-intensity',
      title: 'VO2 max',
      intensity: PolicyWorkoutIntensity.high,
      durationMinutes: 60,
      targetLoad: 85,
    );
    const policy = AdaptiveTrainingPolicy();

    final illness = policy.evaluate(const AdaptiveTrainingPolicyInput(
      plannedWorkout: planned,
      readiness: 80,
      fatigueRisk: 20,
      trainingProgress: 70,
      goalAlignment: 80,
      illnessSymptoms: true,
    ));
    final exhausted = policy.evaluate(const AdaptiveTrainingPolicyInput(
      plannedWorkout: planned,
      readiness: 35,
      fatigueRisk: 85,
      trainingProgress: 70,
      goalAlignment: 80,
      fatigue: 5,
    ));

    expect(illness.decision, PolicyDecision.rest);
    expect(illness.adaptedWorkout.intensity, PolicyWorkoutIntensity.rest);
    expect(
        exhausted.adaptedWorkout.intensity, isNot(PolicyWorkoutIntensity.high));
  });

  test('ordinary plans never exceed two consecutive recovery sessions', () {
    final plan = const AdaptivePlanGenerator().generate(
      start: DateTime(2026, 9, 1),
      goal: TrainingGoal.generalFitness,
      daysPerWeek: 6,
      longRideWeekday: DateTime.sunday,
      ftp: 250,
      currentWeeklyLoad: 300,
      readiness: 30,
      horizonDays: 28,
      recoveryDays: {
        for (var offset = 0; offset < 28; offset++)
          DateTime(2026, 9, 1 + offset),
      },
    );

    var recoveryChain = 0;
    for (final workout in plan) {
      recoveryChain =
          workout.type == SessionType.recovery ? recoveryChain + 1 : 0;
      expect(recoveryChain, lessThanOrEqualTo(2), reason: '${workout.day}');
    }
  });

  test('event blocks cannot leak event intensity beyond the event date', () {
    final demands = const EventDemandModel().calculate(const EventDemandInput(
      type: CyclingEventType.roadRace,
      distanceKm: 120,
      expectedDurationHours: 4,
      elevationMetres: 1500,
      terrain: EventTerrain.hilly,
    ));
    final planner = const StrategicTrainingPlanner();
    final pastEvent = DateTime(2026, 9, 20);
    final today = DateTime(2026, 9, 21);
    final block = planner.buildBlock(StrategicPlanningInput(
      today: today,
      eventDate: pastEvent,
      demands: demands,
      capabilities: AthleteCapabilityProfile(capabilities: const {}),
    ));
    final eligible = const WorkoutFamilyEligibilityEngine().evaluate(
      block: block,
      demands: demands,
    );

    expect(block.phase, TrainingPhase.recoveryTransition);
    expect(block.plannedEndDate.isBefore(block.startDate), isFalse);
    for (final family in const [
      WorkoutFamily.threshold,
      WorkoutFamily.vo2Max,
      WorkoutFamily.anaerobic,
      WorkoutFamily.raceSimulation,
    ]) {
      expect(
        eligible.singleWhere((item) => item.family == family).isEligible,
        isFalse,
        reason: family.name,
      );
    }
  });
}
