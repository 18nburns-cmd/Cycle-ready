import 'dart:math' as math;

class ZoneDuration {
  const ZoneDuration({
    required this.name,
    required this.seconds,
    required this.colorValue,
  });

  final String name;
  final int seconds;
  final int colorValue;
}

class RideAnalysis {
  const RideAnalysis({
    required this.averageSpeedMph,
    required this.intensityFactor,
    required this.powerToWeight,
    required this.powerHeartRateRatio,
    required this.variabilityIndex,
    required this.workKilojoules,
    required this.powerZones,
    required this.heartRateZones,
  });

  final double averageSpeedMph;
  final double? intensityFactor;
  final double? powerToWeight;
  final double? powerHeartRateRatio;
  final double? variabilityIndex;
  final double? workKilojoules;
  final List<ZoneDuration> powerZones;
  final List<ZoneDuration> heartRateZones;
}

RideAnalysis analyseRide({
  required int durationSeconds,
  required double distanceMetres,
  required int ftp,
  required int maximumHeartRate,
  required double weightKg,
  int? averagePower,
  int? averageHeartRate,
  int? normalisedPower,
  required Iterable<({int elapsedSeconds, int? power, int? heartRate})> samples,
}) {
  final speed = durationSeconds <= 0
      ? 0.0
      : distanceMetres / 1609.344 / (durationSeconds / 3600);
  final sorted = samples.toList()
    ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  final powerSeconds = List<int>.filled(6, 0);
  final heartSeconds = List<int>.filled(5, 0);
  for (var i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    final nextSeconds =
        i + 1 < sorted.length ? sorted[i + 1].elapsedSeconds : durationSeconds;
    final seconds = math.max(1, nextSeconds - current.elapsedSeconds);
    if (current.power != null && ftp > 0) {
      powerSeconds[_powerZone(current.power! / ftp)] += seconds;
    }
    if (current.heartRate != null && maximumHeartRate > 0) {
      heartSeconds[_heartRateZone(current.heartRate! / maximumHeartRate)] +=
          seconds;
    }
  }
  return RideAnalysis(
    averageSpeedMph: speed,
    intensityFactor:
        normalisedPower == null || ftp <= 0 ? null : normalisedPower / ftp,
    powerToWeight:
        averagePower == null || weightKg <= 0 ? null : averagePower / weightKg,
    powerHeartRateRatio: averagePower == null ||
            averageHeartRate == null ||
            averageHeartRate <= 0
        ? null
        : averagePower / averageHeartRate,
    variabilityIndex:
        normalisedPower == null || averagePower == null || averagePower <= 0
            ? null
            : normalisedPower / averagePower,
    workKilojoules:
        averagePower == null ? null : averagePower * durationSeconds / 1000,
    powerZones: _zones(powerSeconds, const [
      ('Z1', 0xFF8CB9D0),
      ('Z2', 0xFF55C9A5),
      ('Z3', 0xFF19E56F),
      ('Z4', 0xFFFFD166),
      ('Z5', 0xFFFF9F43),
      ('Z6', 0xFFFF6B6B),
    ]),
    heartRateZones: _zones(heartSeconds, const [
      ('Z1', 0xFF8CB9D0),
      ('Z2', 0xFF55C9A5),
      ('Z3', 0xFF19E56F),
      ('Z4', 0xFFFFB020),
      ('Z5', 0xFFFF6B6B),
    ]),
  );
}

int _powerZone(double ratio) {
  if (ratio < .55) return 0;
  if (ratio < .75) return 1;
  if (ratio < .90) return 2;
  if (ratio < 1.05) return 3;
  if (ratio < 1.20) return 4;
  return 5;
}

int _heartRateZone(double ratio) {
  if (ratio < .60) return 0;
  if (ratio < .70) return 1;
  if (ratio < .80) return 2;
  if (ratio < .90) return 3;
  return 4;
}

List<ZoneDuration> _zones(List<int> seconds, List<(String, int)> definitions) =>
    List.generate(
      seconds.length,
      (index) => ZoneDuration(
        name: definitions[index].$1,
        seconds: seconds[index],
        colorValue: definitions[index].$2,
      ),
    );

class PersonalBestFlags {
  const PersonalBestFlags({
    required this.longestDistance,
    required this.highestElevation,
    required this.highestAveragePower,
    required this.highestTrainingLoad,
  });

  final bool longestDistance;
  final bool highestElevation;
  final bool highestAveragePower;
  final bool highestTrainingLoad;

  bool get any =>
      longestDistance ||
      highestElevation ||
      highestAveragePower ||
      highestTrainingLoad;
}

PersonalBestFlags personalBestFlags({
  required String activityId,
  required Iterable<
          ({
            String id,
            double distance,
            double elevation,
            int? averagePower,
            int? trainingLoad,
          })>
      activities,
}) {
  final rides = activities.toList();
  final selected = rides.where((ride) => ride.id == activityId).firstOrNull;
  if (selected == null) {
    return const PersonalBestFlags(
      longestDistance: false,
      highestElevation: false,
      highestAveragePower: false,
      highestTrainingLoad: false,
    );
  }
  return PersonalBestFlags(
    longestDistance: selected.distance > 0 &&
        selected.distance ==
            rides.map((ride) => ride.distance).reduce(math.max),
    highestElevation: selected.elevation > 0 &&
        selected.elevation ==
            rides.map((ride) => ride.elevation).reduce(math.max),
    highestAveragePower: selected.averagePower != null &&
        selected.averagePower ==
            rides.map((ride) => ride.averagePower ?? 0).reduce(math.max),
    highestTrainingLoad: selected.trainingLoad != null &&
        selected.trainingLoad ==
            rides.map((ride) => ride.trainingLoad ?? 0).reduce(math.max),
  );
}
