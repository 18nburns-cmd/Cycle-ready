enum MobilityPurpose { preRide, postRide, daily }

class MobilityExercise {
  const MobilityExercise({
    required this.id,
    required this.name,
    required this.seconds,
    required this.instructions,
    required this.focus,
    this.sides = 1,
  });

  final String id;
  final String name;
  final int seconds;
  final int sides;
  final String instructions;
  final String focus;

  int get totalSeconds => seconds * sides;
}

class MobilityRoutine {
  const MobilityRoutine({
    required this.name,
    required this.purpose,
    required this.description,
    required this.exercises,
  });

  final String name;
  final MobilityPurpose purpose;
  final String description;
  final List<MobilityExercise> exercises;

  int get minutes =>
      (exercises.fold<int>(0, (sum, item) => sum + item.totalSeconds) / 60)
          .ceil();
}

const mobilityRoutines = <MobilityRoutine>[
  MobilityRoutine(
    name: 'Pre-ride activation',
    purpose: MobilityPurpose.preRide,
    description:
        'Dynamic movement to open the riding position and switch on the hips without reducing power.',
    exercises: [
      MobilityExercise(
        id: 'cat_cow',
        name: 'Cat-cow flow',
        seconds: 45,
        instructions:
            'Move slowly between a rounded and gently extended spine. Breathe out as you round; never force the lower back.',
        focus: 'Spine · breathing',
      ),
      MobilityExercise(
        id: 'worlds_greatest',
        name: "World's greatest stretch",
        seconds: 35,
        sides: 2,
        instructions:
            'Step into a long lunge, place the inside hand down and rotate the other arm toward the ceiling. Keep the front foot planted.',
        focus: 'Hips · thoracic spine',
      ),
      MobilityExercise(
        id: 'leg_swings',
        name: 'Controlled leg swings',
        seconds: 30,
        sides: 2,
        instructions:
            'Use support and swing one leg forward and back through a comfortable range. Keep the pelvis quiet rather than chasing height.',
        focus: 'Hip flexors · hamstrings',
      ),
      MobilityExercise(
        id: 'glute_bridge_activation',
        name: 'Glute bridge activation',
        seconds: 45,
        instructions:
            'Drive through both heels, lightly tuck the pelvis and squeeze the glutes. Avoid arching the lower back.',
        focus: 'Glutes · trunk',
      ),
      MobilityExercise(
        id: 'ankle_rocks',
        name: 'Ankle rocks',
        seconds: 30,
        sides: 2,
        instructions:
            'Keep the heel down and guide the knee forward over the toes. Move smoothly without the arch collapsing.',
        focus: 'Ankles · calves',
      ),
    ],
  ),
  MobilityRoutine(
    name: 'Post-ride reset',
    purpose: MobilityPurpose.postRide,
    description:
        'Gentle holds for the hips, calves and upper back after time in the cycling position.',
    exercises: [
      MobilityExercise(
        id: 'hip_flexor',
        name: 'Half-kneeling hip-flexor stretch',
        seconds: 45,
        sides: 2,
        instructions:
            'Tuck the pelvis slightly and glide forward until the front of the rear hip stretches. Do not arch the back.',
        focus: 'Hip flexors · quads',
      ),
      MobilityExercise(
        id: 'figure_four',
        name: 'Figure-four glute stretch',
        seconds: 45,
        sides: 2,
        instructions:
            'Cross one ankle over the opposite thigh and draw the legs toward you. Keep the foot gently flexed and stop if the knee hurts.',
        focus: 'Glutes · external rotation',
      ),
      MobilityExercise(
        id: 'calf_wall',
        name: 'Wall calf stretch',
        seconds: 40,
        sides: 2,
        instructions:
            'Keep the rear heel grounded and toes pointing forward. Lean toward the wall without letting the foot roll outward.',
        focus: 'Calves · ankles',
      ),
      MobilityExercise(
        id: 'open_book',
        name: 'Open-book rotation',
        seconds: 40,
        sides: 2,
        instructions:
            'Lie on your side with knees stacked. Rotate the upper arm and ribcage open while keeping the knees together.',
        focus: 'Thoracic spine · chest',
      ),
      MobilityExercise(
        id: 'child_pose',
        name: "Child's pose breathing",
        seconds: 60,
        instructions:
            'Sit the hips toward the heels, reach forward and take slow breaths into the back and sides of the ribcage.',
        focus: 'Back · shoulders · recovery',
      ),
    ],
  ),
  MobilityRoutine(
    name: 'Daily cyclist mobility',
    purpose: MobilityPurpose.daily,
    description:
        'A complete routine for hip rotation, hamstrings, ankles and upper-back movement on easy or rest days.',
    exercises: [
      MobilityExercise(
        id: 'ninety_ninety',
        name: '90/90 hip switches',
        seconds: 60,
        instructions:
            'Sit tall with both knees bent and rotate them from side to side under control. Use your hands if needed.',
        focus: 'Hip rotation',
      ),
      MobilityExercise(
        id: 'adductor_rock',
        name: 'Adductor rock-back',
        seconds: 40,
        sides: 2,
        instructions:
            'From hands and knees, extend one leg sideways and rock the hips back with a neutral spine.',
        focus: 'Inner thigh · hips',
      ),
      MobilityExercise(
        id: 'hamstring_floss',
        name: 'Hamstring floss',
        seconds: 40,
        sides: 2,
        instructions:
            'Straighten and soften the knee rhythmically while keeping the back long. This is movement, not a forced hold.',
        focus: 'Hamstrings · neural mobility',
      ),
      MobilityExercise(
        id: 'couch_stretch',
        name: 'Supported couch stretch',
        seconds: 45,
        sides: 2,
        instructions:
            'Place the rear foot on a low support, squeeze that glute and stay tall. Reduce the range if the knee feels compressed.',
        focus: 'Quads · hip flexors',
      ),
      MobilityExercise(
        id: 'thoracic_extension',
        name: 'Thoracic extension',
        seconds: 60,
        instructions:
            'Rest the elbows on a chair, sit the hips back and let the upper back gently extend while the ribs stay controlled.',
        focus: 'Upper back · shoulders',
      ),
      MobilityExercise(
        id: 'deep_squat',
        name: 'Supported deep-squat hold',
        seconds: 60,
        instructions:
            'Hold a support, sit between the hips and keep the feet planted. Use only a pain-free depth.',
        focus: 'Hips · ankles · posture',
      ),
    ],
  ),
];
