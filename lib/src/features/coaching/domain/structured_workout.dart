enum WorkoutDiscipline { cycling }

enum WorkoutPurpose {
  recovery,
  endurance,
  tempo,
  sweetSpot,
  threshold,
  vo2Max,
  anaerobic,
  sprint,
  neuromuscular,
  cadence,
  climbing,
  raceSimulation,
  strengthEndurance,
}

class WorkoutStep {
  const WorkoutStep({
    required this.name,
    required this.durationSeconds,
    required this.powerLowPercent,
    required this.powerHighPercent,
    required this.rpe,
    this.cadenceLow,
    this.cadenceHigh,
    this.heartRateLowPercent,
    this.heartRateHighPercent,
    this.repetitions = 1,
    this.recoverySeconds = 0,
    this.recoveryPowerPercent = 50,
  });

  final String name;
  final int durationSeconds;
  final int powerLowPercent;
  final int powerHighPercent;
  final int rpe;
  final int? cadenceLow;
  final int? cadenceHigh;
  final int? heartRateLowPercent;
  final int? heartRateHighPercent;
  final int repetitions;
  final int recoverySeconds;
  final int recoveryPowerPercent;
}

class StructuredWorkout {
  const StructuredWorkout({
    required this.id,
    required this.scheduledDay,
    required this.discipline,
    required this.purpose,
    required this.title,
    required this.description,
    required this.selectionReason,
    required this.coachNotes,
    required this.steps,
    required this.expectedAdaptation,
    required this.confidence,
    required this.estimatedFatigue,
    required this.estimatedRecoveryHours,
    required this.targetLoad,
  });

  final String id;
  final DateTime scheduledDay;
  final WorkoutDiscipline discipline;
  final WorkoutPurpose purpose;
  final String title;
  final String description;
  final String selectionReason;
  final String coachNotes;
  final List<WorkoutStep> steps;
  final String expectedAdaptation;
  final double confidence;
  final int estimatedFatigue;
  final int estimatedRecoveryHours;
  final int targetLoad;

  int get durationSeconds => steps.fold(0, (total, step) {
        final work = step.durationSeconds * step.repetitions;
        final recoveries = step.recoverySeconds * (step.repetitions - 1);
        return total + work + recoveries;
      });
}

enum WorkoutSegmentKind { warmup, work, recovery, cooldown }

class WorkoutProfileSegment {
  const WorkoutProfileSegment({
    required this.durationSeconds,
    required this.lowPercent,
    required this.highPercent,
    required this.kind,
    required this.label,
  });

  final int durationSeconds;
  final int lowPercent;
  final int highPercent;
  final WorkoutSegmentKind kind;
  final String label;
}

List<WorkoutProfileSegment> workoutProfile(StructuredWorkout workout) {
  final result = <WorkoutProfileSegment>[];
  for (var stepIndex = 0; stepIndex < workout.steps.length; stepIndex++) {
    final step = workout.steps[stepIndex];
    final lowerName = step.name.toLowerCase();
    final kind = lowerName.contains('warm')
        ? WorkoutSegmentKind.warmup
        : lowerName.contains('cool')
            ? WorkoutSegmentKind.cooldown
            : WorkoutSegmentKind.work;
    for (var repetition = 0; repetition < step.repetitions; repetition++) {
      result.add(WorkoutProfileSegment(
        durationSeconds: step.durationSeconds,
        lowPercent: step.powerLowPercent,
        highPercent: step.powerHighPercent,
        kind: kind,
        label: step.name,
      ));
      if (repetition < step.repetitions - 1 && step.recoverySeconds > 0) {
        result.add(WorkoutProfileSegment(
          durationSeconds: step.recoverySeconds,
          lowPercent: step.recoveryPowerPercent,
          highPercent: step.recoveryPowerPercent,
          kind: WorkoutSegmentKind.recovery,
          label: 'Recovery',
        ));
      }
    }
  }
  return result;
}

StructuredWorkout buildStructuredWorkout({
  required String id,
  required DateTime day,
  required String sessionType,
  required String title,
  required int requestedMinutes,
  required int targetLoad,
  String? selectionReason,
  double confidence = .75,
}) {
  final lowerTitle = title.toLowerCase();
  final purpose = switch (sessionType) {
    'recovery' => WorkoutPurpose.recovery,
    'endurance' => WorkoutPurpose.endurance,
    'sweetSpot' => WorkoutPurpose.sweetSpot,
    'threshold' => WorkoutPurpose.threshold,
    'vo2Max' => WorkoutPurpose.vo2Max,
    'anaerobic' => WorkoutPurpose.anaerobic,
    'sprint' => WorkoutPurpose.sprint,
    'neuromuscular' => WorkoutPurpose.neuromuscular,
    'cadence' => WorkoutPurpose.cadence,
    'climbing' => WorkoutPurpose.climbing,
    'raceSimulation' => WorkoutPurpose.raceSimulation,
    'strengthEndurance' => WorkoutPurpose.strengthEndurance,
    'tempo' when lowerTitle.contains('sweet spot') => WorkoutPurpose.sweetSpot,
    'tempo' => WorkoutPurpose.tempo,
    'intervals' when lowerTitle.contains('vo2') => WorkoutPurpose.vo2Max,
    'intervals' when lowerTitle.contains('anaerobic') =>
      WorkoutPurpose.anaerobic,
    'intervals' when lowerTitle.contains('sprint') => WorkoutPurpose.sprint,
    'intervals' when lowerTitle.contains('neuromuscular') =>
      WorkoutPurpose.neuromuscular,
    'intervals' when lowerTitle.contains('cadence') => WorkoutPurpose.cadence,
    'intervals' when lowerTitle.contains('climb') => WorkoutPurpose.climbing,
    'intervals' when lowerTitle.contains('race') =>
      WorkoutPurpose.raceSimulation,
    'intervals' when lowerTitle.contains('strength endurance') =>
      WorkoutPurpose.strengthEndurance,
    'intervals' => WorkoutPurpose.threshold,
    _ => WorkoutPurpose.endurance,
  };
  final parsedStructure =
      RegExp(r'(\d+)\D+(\d+)\s*min', caseSensitive: false).firstMatch(title);
  final parsedRepetitions =
      int.tryParse(parsedStructure?.group(1) ?? '');
  final parsedWorkMinutes =
      int.tryParse(parsedStructure?.group(2) ?? '');
  final steps = switch (purpose) {
    WorkoutPurpose.recovery => [
        WorkoutStep(
          name: 'Easy spin',
          durationSeconds: requestedMinutes * 60,
          powerLowPercent: 45,
          powerHighPercent: 55,
          cadenceLow: 85,
          cadenceHigh: 95,
          heartRateLowPercent: 50,
          heartRateHighPercent: 68,
          rpe: 2,
        ),
      ],
    WorkoutPurpose.endurance => [
        const WorkoutStep(
          name: 'Warm up',
          durationSeconds: 600,
          powerLowPercent: 50,
          powerHighPercent: 60,
          rpe: 2,
        ),
        WorkoutStep(
          name: 'Endurance',
          durationSeconds: (requestedMinutes * 60 - 900).clamp(600, 10800),
          powerLowPercent: 60,
          powerHighPercent: 72,
          cadenceLow: 80,
          cadenceHigh: 95,
          heartRateLowPercent: 68,
          heartRateHighPercent: 82,
          rpe: 4,
        ),
        const WorkoutStep(
          name: 'Cool down',
          durationSeconds: 300,
          powerLowPercent: 45,
          powerHighPercent: 55,
          rpe: 2,
        ),
      ],
    WorkoutPurpose.tempo => [
        const WorkoutStep(
          name: 'Warm up',
          durationSeconds: 900,
          powerLowPercent: 50,
          powerHighPercent: 65,
          rpe: 3,
        ),
        WorkoutStep(
          name: 'Tempo',
          durationSeconds: (parsedWorkMinutes ?? 12) * 60,
          powerLowPercent: 82,
          powerHighPercent: 90,
          cadenceLow: 80,
          cadenceHigh: 95,
          heartRateLowPercent: 78,
          heartRateHighPercent: 88,
          rpe: 6,
          repetitions: parsedRepetitions ?? 3,
          recoverySeconds: 300,
        ),
        const WorkoutStep(
          name: 'Cool down',
          durationSeconds: 600,
          powerLowPercent: 45,
          powerHighPercent: 55,
          rpe: 2,
        ),
      ],
    WorkoutPurpose.sweetSpot => [
        const WorkoutStep(
          name: 'Warm up',
          durationSeconds: 900,
          powerLowPercent: 50,
          powerHighPercent: 70,
          rpe: 3,
        ),
        WorkoutStep(
          name: 'Sweet spot',
          durationSeconds: (parsedWorkMinutes ?? 12) * 60,
          powerLowPercent: 88,
          powerHighPercent: 94,
          cadenceLow: 80,
          cadenceHigh: 95,
          heartRateLowPercent: 82,
          heartRateHighPercent: 92,
          rpe: 7,
          repetitions: parsedRepetitions ?? 3,
          recoverySeconds: 300,
        ),
        const WorkoutStep(
          name: 'Cool down',
          durationSeconds: 600,
          powerLowPercent: 45,
          powerHighPercent: 55,
          rpe: 2,
        ),
      ],
    WorkoutPurpose.threshold => [
        const WorkoutStep(
          name: 'Warm up',
          durationSeconds: 900,
          powerLowPercent: 50,
          powerHighPercent: 70,
          rpe: 3,
        ),
        WorkoutStep(
          name: 'Threshold',
          durationSeconds: (parsedWorkMinutes ?? 8) * 60,
          powerLowPercent: 98,
          powerHighPercent: 102,
          cadenceLow: 85,
          cadenceHigh: 95,
          heartRateLowPercent: 88,
          heartRateHighPercent: 96,
          rpe: 8,
          repetitions: parsedRepetitions ?? 4,
          recoverySeconds: 240,
        ),
        const WorkoutStep(
          name: 'Cool down',
          durationSeconds: 600,
          powerLowPercent: 45,
          powerHighPercent: 55,
          rpe: 2,
        ),
      ],
    WorkoutPurpose.vo2Max => _intervalWorkout(
        name: 'VO₂ max',
        workSeconds: 240,
        powerLow: 110,
        powerHigh: 120,
        repetitions: 5,
        recoverySeconds: 240,
        cadenceLow: 90,
        cadenceHigh: 105,
        rpe: 9,
      ),
    WorkoutPurpose.anaerobic => _intervalWorkout(
        name: 'Anaerobic capacity',
        workSeconds: 60,
        powerLow: 130,
        powerHigh: 150,
        repetitions: 8,
        recoverySeconds: 180,
        cadenceLow: 95,
        cadenceHigh: 110,
        rpe: 10,
      ),
    WorkoutPurpose.sprint || WorkoutPurpose.neuromuscular => _intervalWorkout(
        name: purpose == WorkoutPurpose.sprint ? 'Sprint' : 'Neuromuscular',
        workSeconds: 12,
        powerLow: 150,
        powerHigh: 200,
        repetitions: 8,
        recoverySeconds: 180,
        cadenceLow: 100,
        cadenceHigh: 125,
        rpe: 10,
      ),
    WorkoutPurpose.cadence => _intervalWorkout(
        name: 'High cadence',
        workSeconds: 300,
        powerLow: 60,
        powerHigh: 70,
        repetitions: 6,
        recoverySeconds: 120,
        cadenceLow: 100,
        cadenceHigh: 115,
        rpe: 5,
      ),
    WorkoutPurpose.climbing ||
    WorkoutPurpose.strengthEndurance =>
      _intervalWorkout(
        name: purpose == WorkoutPurpose.climbing
            ? 'Climbing strength'
            : 'Strength endurance',
        workSeconds: 480,
        powerLow: 85,
        powerHigh: 95,
        repetitions: 4,
        recoverySeconds: 240,
        cadenceLow: 55,
        cadenceHigh: 70,
        rpe: 7,
      ),
    WorkoutPurpose.raceSimulation => _intervalWorkout(
        name: 'Race simulation',
        workSeconds: 600,
        powerLow: 95,
        powerHigh: 110,
        repetitions: 4,
        recoverySeconds: 300,
        cadenceLow: 85,
        cadenceHigh: 105,
        rpe: 9,
      ),
  };
  return StructuredWorkout(
    id: id,
    scheduledDay: day,
    discipline: WorkoutDiscipline.cycling,
    purpose: purpose,
    title: title,
    description: 'A personalised ${purpose.name} cycling session.',
    selectionReason: selectionReason ??
        'Selected from your current readiness and training balance.',
    coachNotes: 'Keep the targets controlled and stop if pain develops.',
    steps: steps,
    expectedAdaptation: switch (purpose) {
      WorkoutPurpose.recovery => 'Promote recovery without adding fatigue.',
      WorkoutPurpose.endurance => 'Improve aerobic durability and efficiency.',
      WorkoutPurpose.tempo => 'Build sustained aerobic power.',
      WorkoutPurpose.sweetSpot =>
        'Raise sustainable power with manageable fatigue.',
      WorkoutPurpose.threshold => 'Improve sustainable threshold power.',
      WorkoutPurpose.vo2Max => 'Increase maximal aerobic power.',
      WorkoutPurpose.anaerobic => 'Develop repeatable power above VO₂ max.',
      WorkoutPurpose.sprint ||
      WorkoutPurpose.neuromuscular =>
        'Improve peak force, acceleration and recruitment.',
      WorkoutPurpose.cadence => 'Improve pedalling coordination and economy.',
      WorkoutPurpose.climbing ||
      WorkoutPurpose.strengthEndurance =>
        'Build torque and fatigue resistance for sustained climbing.',
      WorkoutPurpose.raceSimulation =>
        'Practise repeated race-intensity changes under fatigue.',
    },
    confidence: confidence.clamp(0, 1),
    estimatedFatigue: targetLoad.clamp(0, 100),
    estimatedRecoveryHours: (targetLoad * .45).round().clamp(4, 48),
    targetLoad: targetLoad,
  );
}

List<WorkoutStep> _intervalWorkout({
  required String name,
  required int workSeconds,
  required int powerLow,
  required int powerHigh,
  required int repetitions,
  required int recoverySeconds,
  required int cadenceLow,
  required int cadenceHigh,
  required int rpe,
}) =>
    [
      const WorkoutStep(
        name: 'Progressive warm up',
        durationSeconds: 900,
        powerLowPercent: 45,
        powerHighPercent: 75,
        rpe: 3,
      ),
      WorkoutStep(
        name: name,
        durationSeconds: workSeconds,
        powerLowPercent: powerLow,
        powerHighPercent: powerHigh,
        cadenceLow: cadenceLow,
        cadenceHigh: cadenceHigh,
        rpe: rpe,
        repetitions: repetitions,
        recoverySeconds: recoverySeconds,
      ),
      const WorkoutStep(
        name: 'Cool down',
        durationSeconds: 600,
        powerLowPercent: 40,
        powerHighPercent: 55,
        rpe: 2,
      ),
    ];
