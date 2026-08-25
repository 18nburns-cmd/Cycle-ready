enum ProgressionAction { increase, repeat, reduce, addReps }

class StrengthSetPerformance {
  const StrengthSetPerformance({
    required this.sessionId,
    required this.completedAt,
    required this.weightKg,
    required this.reps,
    required this.targetReps,
  });

  final int sessionId;
  final DateTime completedAt;
  final double weightKg;
  final int reps;
  final int targetReps;
}

class StrengthProgression {
  const StrengthProgression({
    required this.exerciseId,
    required this.action,
    required this.suggestedWeightKg,
    required this.suggestedReps,
    required this.bestWeightKg,
    required this.bestEstimatedOneRepMax,
    required this.message,
  });

  final String exerciseId;
  final ProgressionAction action;
  final double suggestedWeightKg;
  final int suggestedReps;
  final double bestWeightKg;
  final double bestEstimatedOneRepMax;
  final String message;
}

StrengthProgression? calculateStrengthProgression(
  String exerciseId,
  Iterable<StrengthSetPerformance> history,
) {
  final values = history.toList()
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  if (values.isEmpty) return null;
  final latestSession = values.first.sessionId;
  final latest =
      values.where((value) => value.sessionId == latestSession).toList();
  final target = latest.first.targetReps.clamp(1, 100);
  final averageReps =
      latest.fold<int>(0, (sum, value) => sum + value.reps) / latest.length;
  final currentWeight = latest.map((value) => value.weightKg).reduce(
        (a, b) => a > b ? a : b,
      );
  final bestWeight = values.map((value) => value.weightKg).reduce(
        (a, b) => a > b ? a : b,
      );
  final bestOneRepMax = values
      .map((value) =>
          value.weightKg <= 0 ? 0.0 : value.weightKg * (1 + value.reps / 30))
      .reduce((a, b) => a > b ? a : b);
  final successful = latest.every((value) => value.reps >= target);
  final struggled = averageReps < target * .8;

  if (currentWeight <= 0) {
    final reps = successful ? target + 1 : target;
    return StrengthProgression(
      exerciseId: exerciseId,
      action: successful ? ProgressionAction.addReps : ProgressionAction.repeat,
      suggestedWeightKg: 0,
      suggestedReps: reps,
      bestWeightKg: bestWeight,
      bestEstimatedOneRepMax: bestOneRepMax,
      message: successful
          ? 'All target reps completed. Add 1 rep per set next time.'
          : 'Repeat the target and prioritise controlled technique.',
    );
  }

  if (successful) {
    final increment = currentWeight >= 30 ? 2.5 : 1.0;
    return StrengthProgression(
      exerciseId: exerciseId,
      action: ProgressionAction.increase,
      suggestedWeightKg: currentWeight + increment,
      suggestedReps: target,
      bestWeightKg: bestWeight,
      bestEstimatedOneRepMax: bestOneRepMax,
      message:
          'Targets achieved. Try ${(currentWeight + increment).toStringAsFixed(1)} kg next time.',
    );
  }
  if (struggled) {
    final reduced = (currentWeight * .95 * 2).round() / 2;
    return StrengthProgression(
      exerciseId: exerciseId,
      action: ProgressionAction.reduce,
      suggestedWeightKg: reduced,
      suggestedReps: target,
      bestWeightKg: bestWeight,
      bestEstimatedOneRepMax: bestOneRepMax,
      message: 'Reps fell short. Reduce slightly to $reduced kg and rebuild.',
    );
  }
  return StrengthProgression(
    exerciseId: exerciseId,
    action: ProgressionAction.repeat,
    suggestedWeightKg: currentWeight,
    suggestedReps: target,
    bestWeightKg: bestWeight,
    bestEstimatedOneRepMax: bestOneRepMax,
    message:
        'Repeat ${currentWeight.toStringAsFixed(1)} kg until every set reaches target.',
  );
}
