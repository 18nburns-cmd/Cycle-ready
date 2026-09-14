import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_selection_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection context retains every coaching input immutably', () {
    final recent = <RecentWorkoutLoad>[];
    final responses = <WorkoutFamily, WorkoutResponseSnapshot>{};
    final context = WorkoutSelectionContext(
      forDay: DateTime(2026, 9, 9),
      athleteState: AthleteState(
        profile: const AthleteProfile(
          name: 'Test athlete',
          experienceLevel: 'experienced',
          ftp: 250,
          maximumHeartRate: 190,
          restingHeartRate: 48,
          weightKg: 75,
          weeklyLoadTarget: 400,
        ),
        updatedAt: DateTime(2026, 9, 9),
        fitness: 50,
        fatigue: 45,
        freshness: 5,
        readiness: 76,
        recovery: 80,
      ),
      goal: WorkoutSelectionGoal.ftp,
      phase: WorkoutCataloguePhase.build,
      weeklyIntent: AdaptationTarget.thresholdPower,
      recovery: const WorkoutRecoveryContext(
        readiness: 76,
        confidence: .84,
        sleepScore: 82,
        hrvStatus: 1.05,
        restingHeartRateStatus: .98,
        recoveryHours: 0,
        illnessOrInjury: false,
      ),
      recentLoad: recent,
      availability: defaultCyclingAvailability(),
      availableEquipment: const {
        WorkoutEquipment.bicycle,
        WorkoutEquipment.powerMeter,
      },
      learnedResponses: responses,
    );
    recent.add(RecentWorkoutLoad(
      at: DateTime(2026, 9, 8),
      family: WorkoutFamily.endurance,
      load: 50,
      completed: true,
    ));
    responses[WorkoutFamily.threshold] = const WorkoutResponseSnapshot();

    expect(context.recentLoad, isEmpty);
    expect(context.learnedResponses, isEmpty);
    expect(context.weeklyIntent, AdaptationTarget.thresholdPower);
    expect(context.availableEquipment, contains(WorkoutEquipment.powerMeter));
  });
}
