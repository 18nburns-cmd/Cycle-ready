enum ActivitySource { healthConnect, strava, fitFile, manual, garmin }

class CyclingActivity {
  const CyclingActivity({
    required this.id,
    required this.source,
    this.externalId,
    required this.startedAt,
    required this.duration,
    required this.distanceMetres,
    this.elevationMetres = 0,
    this.averageHeartRate,
    this.maximumHeartRate,
    this.averagePower,
    this.normalisedPower,
    this.averageCadence,
    this.trainingLoad,
  });

  final String id;
  final ActivitySource source;
  final String? externalId;
  final DateTime startedAt;
  final Duration duration;
  final double distanceMetres;
  final double elevationMetres;
  final int? averageHeartRate;
  final int? maximumHeartRate;
  final int? averagePower;
  final int? normalisedPower;
  final int? averageCadence;
  final double? trainingLoad;
}
