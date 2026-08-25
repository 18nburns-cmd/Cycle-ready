import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_workout_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard workout contains coaching and delivery-neutral detail', () {
    final workout = buildStructuredWorkout(
      id: 'test',
      day: DateTime(2026, 8, 25),
      sessionType: 'intervals',
      title: 'Threshold development',
      requestedMinutes: 60,
      targetLoad: 75,
    );
    expect(workout.steps, isNotEmpty);
    expect(workout.coachNotes, isNotEmpty);
    expect(workout.expectedAdaptation, contains('threshold'));
    expect(workout.estimatedRecoveryHours, greaterThan(0));
  });

  test('mock delivery proves planning is provider independent', () async {
    final provider = MockWorkoutDeliveryProvider();
    final workout = buildStructuredWorkout(
      id: 'test',
      day: DateTime(2026, 8, 25),
      sessionType: 'endurance',
      title: 'Endurance',
      requestedMinutes: 60,
      targetLoad: 40,
    );
    final result = await provider.deliver([workout]);
    expect(result.delivered, 1);
    expect(provider.deliveredWorkouts.single.id, 'test');
  });

  test('Intervals renderer preserves repeats and recovery', () {
    final workout = buildStructuredWorkout(
      id: 'test',
      day: DateTime(2026, 8, 25),
      sessionType: 'tempo',
      title: 'Tempo',
      requestedMinutes: 60,
      targetLoad: 60,
    );
    final text = renderIntervalsWorkout(workout);
    expect(text, contains('3x'));
    expect(text, contains('Recovery'));
    expect(text, contains('82-90%'));
  });

  test('recognises sweet spot plans instead of treating them as tempo', () {
    final workout = buildStructuredWorkout(
      id: 'sweet-spot',
      day: DateTime(2026, 8, 25),
      sessionType: 'tempo',
      title: 'Sweet spot · 3 x 12 min',
      requestedMinutes: 70,
      targetLoad: 70,
    );
    expect(workout.purpose, WorkoutPurpose.sweetSpot);
    expect(workout.steps.any((step) => step.powerLowPercent == 88), isTrue);
    final work = workout.steps.firstWhere((step) => step.name == 'Sweet spot');
    expect(work.repetitions, 3);
    expect(work.durationSeconds, 12 * 60);
  });

  test('uses progressive interval structure from the workout title', () {
    final workout = buildStructuredWorkout(
      id: 'progression',
      day: DateTime(2026, 8, 25),
      sessionType: 'intervals',
      title: 'Threshold · 3 × 12 min',
      requestedMinutes: 78,
      targetLoad: 90,
    );
    final work = workout.steps.firstWhere((step) => step.name == 'Threshold');
    expect(work.repetitions, 3);
    expect(work.durationSeconds, 12 * 60);
  });

  test('supports specialist coaching session types', () {
    const types = {
      'vo2Max': WorkoutPurpose.vo2Max,
      'anaerobic': WorkoutPurpose.anaerobic,
      'sprint': WorkoutPurpose.sprint,
      'cadence': WorkoutPurpose.cadence,
      'climbing': WorkoutPurpose.climbing,
      'raceSimulation': WorkoutPurpose.raceSimulation,
      'strengthEndurance': WorkoutPurpose.strengthEndurance,
    };
    for (final entry in types.entries) {
      final workout = buildStructuredWorkout(
        id: entry.key,
        day: DateTime(2026, 8, 25),
        sessionType: entry.key,
        title: entry.key,
        requestedMinutes: 60,
        targetLoad: 70,
      );
      expect(workout.purpose, entry.value);
      expect(workout.steps, isNotEmpty);
    }
  });

  test('profile expands repetitions and inserts recoveries', () {
    final workout = buildStructuredWorkout(
      id: 'profile',
      day: DateTime(2026, 8, 25),
      sessionType: 'vo2Max',
      title: 'VO2 max',
      requestedMinutes: 60,
      targetLoad: 80,
    );
    final profile = workoutProfile(workout);
    expect(
      profile.where((segment) => segment.kind == WorkoutSegmentKind.work),
      hasLength(5),
    );
    expect(
      profile.where((segment) => segment.kind == WorkoutSegmentKind.recovery),
      hasLength(4),
    );
    expect(profile.first.kind, WorkoutSegmentKind.warmup);
    expect(profile.last.kind, WorkoutSegmentKind.cooldown);
  });
}
