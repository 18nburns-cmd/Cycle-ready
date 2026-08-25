enum PlannedWorkoutOutcome { onTarget, underTarget, overTarget, missed }

class WorkoutCompliance {
  const WorkoutCompliance({
    required this.outcome,
    required this.loadRatio,
    required this.durationRatio,
    required this.explanation,
  });

  final PlannedWorkoutOutcome outcome;
  final double loadRatio;
  final double durationRatio;
  final String explanation;

  String get label => switch (outcome) {
        PlannedWorkoutOutcome.onTarget => 'Completed as planned',
        PlannedWorkoutOutcome.underTarget => 'Lighter than planned',
        PlannedWorkoutOutcome.overTarget => 'Harder than planned',
        PlannedWorkoutOutcome.missed => 'Not completed',
      };
}

WorkoutCompliance assessWorkoutCompliance({
  required int plannedLoad,
  required int plannedMinutes,
  required int actualLoad,
  required int actualMinutes,
}) {
  if (actualMinutes <= 0 && actualLoad <= 0) {
    return const WorkoutCompliance(
      outcome: PlannedWorkoutOutcome.missed,
      loadRatio: 0,
      durationRatio: 0,
      explanation:
          'No completed activity was matched to this planned session.',
    );
  }
  final loadRatio = plannedLoad <= 0 ? 1.0 : actualLoad / plannedLoad;
  final durationRatio =
      plannedMinutes <= 0 ? 1.0 : actualMinutes / plannedMinutes;
  if (loadRatio > 1.25 || durationRatio > 1.35) {
    return WorkoutCompliance(
      outcome: PlannedWorkoutOutcome.overTarget,
      loadRatio: loadRatio,
      durationRatio: durationRatio,
      explanation:
          'The completed work exceeded the planned training cost, so the next demanding session may need extra recovery protection.',
    );
  }
  if (loadRatio < .65 || durationRatio < .65) {
    return WorkoutCompliance(
      outcome: PlannedWorkoutOutcome.underTarget,
      loadRatio: loadRatio,
      durationRatio: durationRatio,
      explanation:
          'The ride delivered less stimulus than planned. CycleReady will continue the progression without forcing the missed load into one session.',
    );
  }
  return WorkoutCompliance(
    outcome: PlannedWorkoutOutcome.onTarget,
    loadRatio: loadRatio,
    durationRatio: durationRatio,
    explanation:
        'Duration and training load were close enough to deliver the intended session stimulus.',
  );
}
