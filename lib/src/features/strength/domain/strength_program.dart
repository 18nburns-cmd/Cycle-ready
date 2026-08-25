enum StrengthGoal { cyclingPerformance, generalStrength, muscleGain, mobility }

enum TrainingLocation { home, gym }

enum StrengthExperience { beginner, intermediate, experienced }

class StrengthExercise {
  const StrengthExercise({
    required this.id,
    required this.name,
    required this.instructions,
    required this.muscles,
    required this.homeFriendly,
    required this.defaultSets,
    required this.defaultReps,
  });
  final String id;
  final String name;
  final String instructions;
  final String muscles;
  final bool homeFriendly;
  final int defaultSets;
  final int defaultReps;
}

class StrengthRoutine {
  const StrengthRoutine({
    required this.name,
    required this.focus,
    required this.exercises,
  });
  final String name;
  final String focus;
  final List<StrengthExercise> exercises;
}

const strengthExercises = <StrengthExercise>[
  StrengthExercise(
      id: 'squat',
      name: 'Goblet squat',
      instructions:
          'Hold the weight close to your chest. Brace, sit between your hips, keep knees tracking over toes, then drive through the whole foot.',
      muscles: 'Quads · glutes · core',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 8),
  StrengthExercise(
      id: 'split_squat',
      name: 'Rear-foot elevated split squat',
      instructions:
          'Place the rear foot on a low support. Lower the back knee under control while keeping the front foot planted, then stand tall.',
      muscles: 'Quads · glutes · balance',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 8),
  StrengthExercise(
      id: 'deadlift',
      name: 'Romanian deadlift',
      instructions:
          'Soften the knees, push the hips back with a neutral spine, lower until the hamstrings tighten, then squeeze the glutes to stand.',
      muscles: 'Hamstrings · glutes · back',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 8),
  StrengthExercise(
      id: 'calf',
      name: 'Single-leg calf raise',
      instructions:
          'Use light support, rise onto the ball of one foot, pause at the top and lower slowly through a full range.',
      muscles: 'Calves · ankle stability',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 12),
  StrengthExercise(
      id: 'row',
      name: 'Dumbbell or cable row',
      instructions:
          'Brace the torso, pull the elbow toward the back pocket without shrugging, pause, then lower with control.',
      muscles: 'Upper back · arms',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 10),
  StrengthExercise(
      id: 'push_up',
      name: 'Push-up or chest press',
      instructions:
          'Keep ribs and hips aligned. Lower the chest under control, keep elbows slightly tucked and press away firmly.',
      muscles: 'Chest · shoulders · triceps',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 10),
  StrengthExercise(
      id: 'lat_pull',
      name: 'Lat pulldown',
      instructions:
          'Set the shoulders down, pull the bar toward the upper chest, drive elbows down and return without swinging.',
      muscles: 'Lats · upper back · arms',
      homeFriendly: false,
      defaultSets: 3,
      defaultReps: 10),
  StrengthExercise(
      id: 'leg_press',
      name: 'Leg press',
      instructions:
          'Plant the whole foot, lower until the hips remain stable, then press without locking the knees.',
      muscles: 'Quads · glutes',
      homeFriendly: false,
      defaultSets: 3,
      defaultReps: 10),
  StrengthExercise(
      id: 'plank',
      name: 'Front plank',
      instructions:
          'Brace as if preparing for a punch. Keep a straight line from shoulders to heels and breathe behind the brace.',
      muscles: 'Core · shoulders',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 30),
  StrengthExercise(
      id: 'side_plank',
      name: 'Side plank',
      instructions:
          'Stack the shoulders and hips, press the floor away and hold a straight line without rotating forward.',
      muscles: 'Obliques · hip stability',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 25),
  StrengthExercise(
      id: 'bridge',
      name: 'Single-leg glute bridge',
      instructions:
          'Brace the trunk, drive through one heel and lift the hips without arching the lower back.',
      muscles: 'Glutes · hamstrings',
      homeFriendly: true,
      defaultSets: 3,
      defaultReps: 10),
  StrengthExercise(
      id: 'mobility',
      name: 'Hip and thoracic mobility flow',
      instructions:
          'Move slowly through a hip-flexor stretch, deep squat hold and open-book rotation. Never force painful range.',
      muscles: 'Hips · back · mobility',
      homeFriendly: true,
      defaultSets: 2,
      defaultReps: 6),
];

List<StrengthRoutine> buildStrengthProgram({
  required StrengthGoal goal,
  required TrainingLocation location,
  required StrengthExperience experience,
  required int daysPerWeek,
}) {
  StrengthExercise exercise(String id) =>
      strengthExercises.firstWhere((value) => value.id == id);
  final gym = location == TrainingLocation.gym;
  final lower = [
    exercise(gym ? 'leg_press' : 'squat'),
    exercise('deadlift'),
    exercise('split_squat'),
    exercise('calf'),
    exercise('plank')
  ];
  final upper = [
    exercise('row'),
    exercise(gym ? 'lat_pull' : 'push_up'),
    exercise('push_up'),
    exercise('side_plank'),
    exercise('mobility')
  ];
  final full = [
    exercise('squat'),
    exercise('deadlift'),
    exercise('row'),
    exercise('push_up'),
    exercise('bridge'),
    exercise('plank')
  ];
  final mobility = [
    exercise('mobility'),
    exercise('bridge'),
    exercise('side_plank'),
    exercise('calf')
  ];
  final routines = goal == StrengthGoal.mobility
      ? [
          StrengthRoutine(
              name: 'Mobility & resilience',
              focus: 'Restore movement and trunk control',
              exercises: mobility)
        ]
      : goal == StrengthGoal.cyclingPerformance
          ? [
              StrengthRoutine(
                  name: 'Cycling strength',
                  focus: 'Force production and injury resilience',
                  exercises: lower),
              StrengthRoutine(
                  name: 'Core & posture',
                  focus: 'Stable power and riding posture',
                  exercises: upper)
            ]
          : [
              StrengthRoutine(
                  name: 'Full body A',
                  focus: goal == StrengthGoal.muscleGain
                      ? 'Hypertrophy and balanced development'
                      : 'Whole-body strength',
                  exercises: full),
              StrengthRoutine(
                  name: 'Full body B',
                  focus: 'Movement balance and progression',
                  exercises: [...upper.take(3), ...lower.take(3)])
            ];
  return List.generate(
      daysPerWeek.clamp(1, 4), (index) => routines[index % routines.length]);
}
