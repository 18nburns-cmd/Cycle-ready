import 'package:cycle_ready/src/features/strength/domain/custom_strength_workout.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leg focus only returns relevant exercises', () {
    final exercises = exercisesForFocus(
      MuscleFocus.legs,
      location: TrainingLocation.gym,
    );
    expect(exercises.map((item) => item.id), contains('squat'));
    expect(exercises.map((item) => item.id), contains('leg_press'));
    expect(exercises.map((item) => item.id), isNot(contains('push_up')));
  });

  test('home focus removes gym-only exercises', () {
    final exercises = exercisesForFocus(
      MuscleFocus.back,
      location: TrainingLocation.home,
    );
    expect(exercises.map((item) => item.id), contains('row'));
    expect(exercises.map((item) => item.id), isNot(contains('lat_pull')));
  });

  test('arms and back are available as separate selections', () {
    expect(
      exercisesForFocus(MuscleFocus.arms, location: TrainingLocation.gym),
      isNotEmpty,
    );
    expect(
      exercisesForFocus(MuscleFocus.back, location: TrainingLocation.gym),
      isNotEmpty,
    );
  });
}
