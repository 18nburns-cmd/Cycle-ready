class HealthSnapshot {
  const HealthSnapshot({
    this.sleepMinutes,
    this.sleepEndedAt,
    this.restingHeartRate,
    this.restingHeartRateEstimated = false,
    this.hrvMilliseconds,
    this.weightKg,
    this.bodyFatPercent,
    this.workoutCount = 0,
    this.sources = const [],
    this.workouts = const [],
    this.bodyMeasurements = const [],
    required this.syncedAt,
  });

  final int? sleepMinutes;
  final DateTime? sleepEndedAt;
  final double? restingHeartRate;
  final bool restingHeartRateEstimated;
  final double? hrvMilliseconds;
  final double? weightKg;
  final double? bodyFatPercent;
  final int workoutCount;
  final List<String> sources;
  final List<ImportedWorkout> workouts;
  final List<ImportedBodyMeasurement> bodyMeasurements;
  final DateTime syncedAt;
}

class ImportedBodyMeasurement {
  const ImportedBodyMeasurement({
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
    required this.source,
  });
  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
  final String source;
}

class ImportedWorkout {
  const ImportedWorkout({
    required this.externalId,
    required this.source,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMetres,
    required this.calories,
  });
  final String externalId;
  final String source;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final int? calories;
}
