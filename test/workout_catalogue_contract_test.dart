import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable workout id is deterministic and provider neutral', () {
    final first = WorkoutVariantId.compose(
      family: WorkoutFamily.vo2Max,
      variant: '5 x 4 minutes',
    );
    final second = WorkoutVariantId.compose(
      family: WorkoutFamily.vo2Max,
      variant: '5 x 4 minutes',
    );

    expect(first, second);
    expect(first.value, 'vo2max-5-x-4-minutes-v1');
    expect(first.value, isNot(contains('intervals')));
  });

  test('stable workout id rejects malformed and unversioned values', () {
    expect(() => WorkoutVariantId.parse('Threshold 4x8'),
        throwsA(isA<FormatException>()));
    expect(
      () => WorkoutVariantId.compose(
        family: WorkoutFamily.threshold,
        variant: '',
      ),
      throwsArgumentError,
    );
  });

  test('progression links immutable variant identities', () {
    final easier = WorkoutVariantId.compose(
      family: WorkoutFamily.threshold,
      variant: '4 x 6 minutes',
    );
    final harder = WorkoutVariantId.compose(
      family: WorkoutFamily.threshold,
      variant: '4 x 8 minutes',
    );
    final progression = WorkoutProgression(from: easier, to: harder);

    expect(progression.isSelfReference, isFalse);
    expect(progression.from, easier);
    expect(progression.to, harder);
  });

  test('variant carries provider-neutral coaching constraints and outcomes',
      () {
    final variant = WorkoutVariant(
      id: WorkoutVariantId.compose(
        family: WorkoutFamily.climbingEndurance,
        variant: 'low cadence 4 x 8',
      ),
      family: WorkoutFamily.climbingEndurance,
      name: 'Climbing strength 4 × 8',
      difficulty: WorkoutDifficulty.developing,
      durationMinutes: 67,
      adaptationTarget: AdaptationTarget.muscularEndurance,
      estimatedRecoveryHours: 24,
      cadenceRange: (60, 70),
      terrain: WorkoutTerrain.sustainedClimb,
      requiredEquipment: const {
        WorkoutEquipment.bicycle,
        WorkoutEquipment.powerMeter,
      },
      successCriteria: const [
        WorkoutSuccessCriterion(
          metric: 'work_interval_power_completion',
          minimum: .90,
          maximum: 1,
          unit: 'ratio',
        ),
      ],
      steps: const [
        WorkoutCatalogueStep(
          role: WorkoutStepRole.warmUp,
          durationSeconds: 600,
          powerLowPercent: 45,
          powerHighPercent: 70,
        ),
        WorkoutCatalogueStep(
          role: WorkoutStepRole.work,
          durationSeconds: 480,
          powerLowPercent: 88,
          powerHighPercent: 94,
          repetitions: 4,
          cadenceLow: 60,
          cadenceHigh: 70,
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
      phases: const {
        WorkoutCataloguePhase.foundation,
        WorkoutCataloguePhase.build,
      },
    );

    expect(variant.cadenceRange, (60, 70));
    expect(variant.terrain, WorkoutTerrain.sustainedClimb);
    expect(variant.successCriteria.single.minimum, .90);
    expect(
      variant.steps.map((step) => step.role),
      WorkoutStepRole.values,
    );
  });

  test('contract exposes every currently supported workout family', () {
    expect(WorkoutFamily.values, hasLength(16));
    expect(WorkoutFamily.values, contains(WorkoutFamily.raceSimulation));
    expect(WorkoutFamily.values, contains(WorkoutFamily.fatigueResistance));
  });
}
