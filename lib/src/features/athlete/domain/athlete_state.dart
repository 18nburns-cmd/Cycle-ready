import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';

class AthleteState {
  const AthleteState({
    required this.profile,
    required this.updatedAt,
    required this.fitness,
    required this.fatigue,
    required this.freshness,
    required this.readiness,
    required this.recovery,
    this.hrvTrend,
    this.weightTrend,
  });

  final AthleteProfile profile;
  final DateTime updatedAt;
  final double fitness;
  final double fatigue;
  final double freshness;
  final double readiness;
  final double recovery;
  final double? hrvTrend;
  final double? weightTrend;

  AthleteState copyWith({
    AthleteProfile? profile,
    DateTime? updatedAt,
    double? fitness,
    double? fatigue,
    double? freshness,
    double? readiness,
    double? recovery,
    double? hrvTrend,
    double? weightTrend,
  }) =>
      AthleteState(
        profile: profile ?? this.profile,
        updatedAt: updatedAt ?? this.updatedAt,
        fitness: fitness ?? this.fitness,
        fatigue: fatigue ?? this.fatigue,
        freshness: freshness ?? this.freshness,
        readiness: readiness ?? this.readiness,
        recovery: recovery ?? this.recovery,
        hrvTrend: hrvTrend ?? this.hrvTrend,
        weightTrend: weightTrend ?? this.weightTrend,
      );
}
