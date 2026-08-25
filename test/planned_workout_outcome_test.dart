import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies completed workout close to planned load', () {
    final result = assessWorkoutCompliance(
      plannedLoad: 70,
      plannedMinutes: 60,
      actualLoad: 74,
      actualMinutes: 58,
    );
    expect(result.outcome, PlannedWorkoutOutcome.onTarget);
  });

  test('classifies a materially harder workout', () {
    final result = assessWorkoutCompliance(
      plannedLoad: 60,
      plannedMinutes: 60,
      actualLoad: 85,
      actualMinutes: 70,
    );
    expect(result.outcome, PlannedWorkoutOutcome.overTarget);
  });

  test('classifies short and missed workouts', () {
    expect(
      assessWorkoutCompliance(
        plannedLoad: 60,
        plannedMinutes: 60,
        actualLoad: 25,
        actualMinutes: 25,
      ).outcome,
      PlannedWorkoutOutcome.underTarget,
    );
    expect(
      assessWorkoutCompliance(
        plannedLoad: 60,
        plannedMinutes: 60,
        actualLoad: 0,
        actualMinutes: 0,
      ).outcome,
      PlannedWorkoutOutcome.missed,
    );
  });
}
