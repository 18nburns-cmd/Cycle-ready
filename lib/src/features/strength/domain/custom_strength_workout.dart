import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';

enum MuscleFocus { fullBody, legs, back, arms, chestShoulders, core }

String muscleFocusLabel(MuscleFocus focus) => switch (focus) {
      MuscleFocus.fullBody => 'Full body',
      MuscleFocus.legs => 'Legs',
      MuscleFocus.back => 'Back',
      MuscleFocus.arms => 'Arms',
      MuscleFocus.chestShoulders => 'Chest & shoulders',
      MuscleFocus.core => 'Core',
    };

const _exerciseGroups = <MuscleFocus, Set<String>>{
  MuscleFocus.fullBody: {
    'squat',
    'split_squat',
    'deadlift',
    'calf',
    'row',
    'push_up',
    'lat_pull',
    'leg_press',
    'plank',
    'side_plank',
    'bridge',
    'mobility',
  },
  MuscleFocus.legs: {
    'squat',
    'split_squat',
    'deadlift',
    'calf',
    'leg_press',
    'bridge',
  },
  MuscleFocus.back: {'deadlift', 'row', 'lat_pull', 'mobility'},
  MuscleFocus.arms: {'row', 'push_up', 'lat_pull'},
  MuscleFocus.chestShoulders: {'push_up', 'plank', 'side_plank'},
  MuscleFocus.core: {'plank', 'side_plank', 'bridge', 'mobility'},
};

List<StrengthExercise> exercisesForFocus(
  MuscleFocus focus, {
  required TrainingLocation location,
}) {
  final ids = _exerciseGroups[focus]!;
  return strengthExercises
      .where((exercise) => ids.contains(exercise.id))
      .where((exercise) =>
          location == TrainingLocation.gym || exercise.homeFriendly)
      .toList();
}
