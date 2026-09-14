import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = WorkoutGenerator();
  const validator = WorkoutValidator();
  final context = WorkoutGenerationContext(
    id: 'generated-1',
    day: DateTime.utc(2026, 8, 26),
    durationMinutes: 60,
    targetLoad: 70,
    reason: 'Readiness and training history support this session.',
    confidence: .82,
  );

  test('warm-up and cool-down generators produce valid bounded steps', () {
    final warmUp = const WarmUpGenerator().generate(highIntensity: true);
    final coolDown = const CoolDownGenerator().generate();

    expect(warmUp.powerHighPercent, 75);
    expect(coolDown.powerLowPercent, lessThan(coolDown.powerHighPercent));
  });

  test('generates every backlog workout family with rationale and confidence',
      () {
    final workouts = [
      generator.recovery(context),
      generator.endurance(context),
      generator.tempo(context),
      generator.sweetSpot(context),
      generator.threshold(context),
      generator.vo2Max(context),
      generator.anaerobic(context),
      generator.sprint(context),
      generator.climbing(context),
    ];

    expect(workouts.map((workout) => workout.purpose).toSet(), hasLength(9));
    for (final workout in workouts) {
      expect(workout.selectionReason, context.reason);
      expect(workout.confidence, context.confidence);
      expect(validator.validate(workout).isValid, isTrue);
    }
  });

  test('validator reports unsafe step values', () {
    final invalid = StructuredWorkout(
      id: '',
      scheduledDay: context.day,
      discipline: WorkoutDiscipline.cycling,
      purpose: WorkoutPurpose.threshold,
      title: 'Invalid',
      description: 'Invalid test workout',
      selectionReason: context.reason,
      coachNotes: '',
      steps: const [
        WorkoutStep(
          name: 'Broken',
          durationSeconds: 0,
          powerLowPercent: 100,
          powerHighPercent: 90,
          rpe: 8,
        ),
      ],
      expectedAdaptation: '',
      confidence: 1.2,
      estimatedFatigue: 0,
      estimatedRecoveryHours: 0,
      targetLoad: 0,
    );

    expect(validator.validate(invalid).errors, hasLength(4));
  });
}
