import 'package:cycle_ready/src/features/strength/domain/mobility_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides pre-ride, post-ride and daily cyclist routines', () {
    expect(
      mobilityRoutines.map((routine) => routine.purpose).toSet(),
      containsAll(MobilityPurpose.values),
    );
    expect(
      mobilityRoutines.every((routine) => routine.exercises.length >= 5),
      isTrue,
    );
  });

  test('bilateral movements include time for both sides', () {
    final stretch = mobilityRoutines
        .expand((routine) => routine.exercises)
        .firstWhere((exercise) => exercise.sides == 2);
    expect(stretch.totalSeconds, stretch.seconds * 2);
  });

  test('every routine has a practical guided duration', () {
    expect(
      mobilityRoutines.every(
        (routine) => routine.minutes >= 4 && routine.minutes <= 15,
      ),
      isTrue,
    );
  });
}
