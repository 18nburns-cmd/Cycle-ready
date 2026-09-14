import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';

class AthleteStateTrend {
  const AthleteStateTrend({
    required this.from,
    required this.to,
    required this.fitnessChange,
    required this.fatigueChange,
    required this.freshnessChange,
    required this.readinessChange,
    required this.recoveryChange,
    required this.weightChangeKg,
  });

  final DateTime from;
  final DateTime to;
  final double fitnessChange;
  final double fatigueChange;
  final double freshnessChange;
  final double readinessChange;
  final double recoveryChange;
  final double weightChangeKg;
}

AthleteStateTrend? calculateAthleteStateTrend(
  Iterable<AthleteState> snapshots,
) {
  final ordered = snapshots.toList(growable: false)
    ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  if (ordered.length < 2) return null;

  final first = ordered.first;
  final latest = ordered.last;
  return AthleteStateTrend(
    from: first.updatedAt,
    to: latest.updatedAt,
    fitnessChange: latest.fitness - first.fitness,
    fatigueChange: latest.fatigue - first.fatigue,
    freshnessChange: latest.freshness - first.freshness,
    readinessChange: latest.readiness - first.readiness,
    recoveryChange: latest.recovery - first.recovery,
    weightChangeKg: latest.profile.weightKg - first.profile.weightKg,
  );
}
