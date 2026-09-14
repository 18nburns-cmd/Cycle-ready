import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable IDs are unique across every family and difficulty', () {
    final ids = <WorkoutVariantId>{};
    for (final family in WorkoutFamily.values) {
      for (final difficulty in WorkoutDifficulty.values) {
        ids.add(WorkoutVariantId.compose(
          family: family,
          variant: difficulty.name,
        ));
      }
    }

    expect(ids, hasLength(WorkoutFamily.values.length * 3));
  });

  test('every family has a complete non-cyclic progression path', () {
    for (final family in WorkoutFamily.values) {
      final introductory = WorkoutVariantId.compose(
        family: family,
        variant: WorkoutDifficulty.introductory.name,
      );
      final developing = WorkoutVariantId.compose(
        family: family,
        variant: WorkoutDifficulty.developing.name,
      );
      final advanced = WorkoutVariantId.compose(
        family: family,
        variant: WorkoutDifficulty.advanced.name,
      );
      final progression = [
        WorkoutProgression(from: introductory, to: developing),
        WorkoutProgression(from: developing, to: advanced),
      ];

      expect(progression.any((edge) => edge.isSelfReference), isFalse);
      expect(progression.first.from, introductory);
      expect(progression.last.to, advanced);
    }
  });
}
