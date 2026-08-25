import 'dart:math' as math;

class StrengthWorkoutLoad {
  const StrengthWorkoutLoad({
    required this.sessionId,
    required this.startedAt,
    required this.completedAt,
    required this.durationMinutes,
    required this.completedSets,
    required this.volumeKg,
    required this.load,
  });

  final int sessionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationMinutes;
  final int completedSets;
  final double volumeKg;
  final double load;
}

double estimateStrengthTrainingLoad({
  required int durationMinutes,
  required int completedSets,
  required double volumeKg,
}) {
  if (completedSets <= 0 || durationMinutes <= 0) return 0;
  final durationContribution = durationMinutes.clamp(1, 180) * .45;
  final setContribution = completedSets.clamp(1, 40) * 1.5;
  final volumeContribution = math.sqrt(math.max(0, volumeKg)) * .15;
  return (durationContribution + setContribution + volumeContribution)
      .clamp(5, 100)
      .toDouble();
}
