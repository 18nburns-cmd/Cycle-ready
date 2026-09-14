import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue_validator.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutVariant variant({List<WorkoutCatalogueStep>? steps}) => WorkoutVariant(
      id: WorkoutVariantId.compose(
        family: WorkoutFamily.threshold,
        variant: '4 x 8',
      ),
      family: WorkoutFamily.threshold,
      name: 'Threshold 4 × 8',
      difficulty: WorkoutDifficulty.developing,
      durationMinutes: 65,
      adaptationTarget: AdaptationTarget.thresholdPower,
      estimatedRecoveryHours: 32,
      steps: steps ??
          const [
            WorkoutCatalogueStep(
              role: WorkoutStepRole.warmUp,
              durationSeconds: 600,
              powerLowPercent: 45,
              powerHighPercent: 70,
            ),
            WorkoutCatalogueStep(
              role: WorkoutStepRole.work,
              durationSeconds: 480,
              powerLowPercent: 98,
              powerHighPercent: 103,
              repetitions: 4,
            ),
            WorkoutCatalogueStep(
              role: WorkoutStepRole.recovery,
              durationSeconds: 240,
              powerLowPercent: 40,
              powerHighPercent: 55,
              repetitions: 3,
            ),
            WorkoutCatalogueStep(
              role: WorkoutStepRole.coolDown,
              durationSeconds: 600,
              powerLowPercent: 40,
              powerHighPercent: 55,
            ),
          ],
    );

void main() {
  const validator = WorkoutCatalogueValidator();

  test('accepts a complete structured catalogue variant', () {
    expect(validator.validate(variant()).isValid, isTrue);
  });

  test('rejects missing phases and unsafe step targets', () {
    final invalid = variant(steps: const [
      WorkoutCatalogueStep(
        role: WorkoutStepRole.work,
        durationSeconds: 0,
        powerLowPercent: 260,
        powerHighPercent: 200,
        cadenceLow: 120,
      ),
    ]);
    final errors = validator.validate(invalid).errors;

    expect(errors, contains('The first step must be a warm-up.'));
    expect(errors, contains('The last step must be a cool-down.'));
    expect(errors.any((error) => error.contains('power range')), isTrue);
    expect(errors.any((error) => error.contains('cadence range')), isTrue);
    expect(errors,
        contains('Structured steps must match the declared total duration.'));
  });
}
