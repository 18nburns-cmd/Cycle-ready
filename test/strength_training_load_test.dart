import 'package:cycle_ready/src/features/strength/domain/strength_training_load.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strength load rises with duration, sets and lifted volume', () {
    final short = estimateStrengthTrainingLoad(
      durationMinutes: 25,
      completedSets: 6,
      volumeKg: 1200,
    );
    final demanding = estimateStrengthTrainingLoad(
      durationMinutes: 60,
      completedSets: 18,
      volumeKg: 6500,
    );
    expect(short, greaterThan(5));
    expect(demanding, greaterThan(short));
    expect(demanding, lessThanOrEqualTo(100));
  });

  test('an unfinished workout contributes no load', () {
    expect(
      estimateStrengthTrainingLoad(
        durationMinutes: 45,
        completedSets: 0,
        volumeKg: 0,
      ),
      0,
    );
  });
}
