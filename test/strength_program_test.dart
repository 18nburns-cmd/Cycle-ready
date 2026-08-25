import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home cycling plan avoids gym-only exercises', () {
    final program = buildStrengthProgram(
      goal: StrengthGoal.cyclingPerformance,
      location: TrainingLocation.home,
      experience: StrengthExperience.beginner,
      daysPerWeek: 2,
    );
    expect(program, hasLength(2));
    expect(
      program.expand((routine) => routine.exercises).every(
            (exercise) => exercise.homeFriendly,
          ),
      isTrue,
    );
  });

  test('programme follows selected weekly frequency', () {
    final program = buildStrengthProgram(
      goal: StrengthGoal.generalStrength,
      location: TrainingLocation.gym,
      experience: StrengthExperience.intermediate,
      daysPerWeek: 3,
    );
    expect(program, hasLength(3));
    expect(program.every((routine) => routine.exercises.isNotEmpty), isTrue);
  });
}
