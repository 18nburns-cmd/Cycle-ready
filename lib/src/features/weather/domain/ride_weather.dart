enum RidingSafetyProfile { cautious, balanced, resilient }

class RidingSafetyThresholds {
  const RidingSafetyThresholds({
    required this.minimumTemperatureC,
    required this.maximumTemperatureC,
    required this.maximumPrecipitationProbability,
    required this.maximumWindGustKph,
  });

  final double minimumTemperatureC;
  final double maximumTemperatureC;
  final int maximumPrecipitationProbability;
  final double maximumWindGustKph;

  factory RidingSafetyThresholds.forProfile(RidingSafetyProfile profile) =>
      switch (profile) {
        RidingSafetyProfile.cautious => const RidingSafetyThresholds(
            minimumTemperatureC: 4,
            maximumTemperatureC: 30,
            maximumPrecipitationProbability: 65,
            maximumWindGustKph: 45,
          ),
        RidingSafetyProfile.balanced => const RidingSafetyThresholds(
            minimumTemperatureC: 1,
            maximumTemperatureC: 35,
            maximumPrecipitationProbability: 80,
            maximumWindGustKph: 55,
          ),
        RidingSafetyProfile.resilient => const RidingSafetyThresholds(
            minimumTemperatureC: -1,
            maximumTemperatureC: 38,
            maximumPrecipitationProbability: 90,
            maximumWindGustKph: 65,
          ),
      };
}

class RideWeather {
  const RideWeather({
    required this.at,
    required this.temperatureC,
    required this.precipitationMm,
    required this.precipitationProbability,
    required this.windGustKph,
    required this.weatherCode,
  });

  final DateTime at;
  final double temperatureC;
  final double precipitationMm;
  final int precipitationProbability;
  final double windGustKph;
  final int weatherCode;

  bool isUnsafe(RidingSafetyThresholds thresholds) =>
      temperatureC <= thresholds.minimumTemperatureC ||
      temperatureC >= thresholds.maximumTemperatureC ||
      precipitationMm >= 3 ||
      precipitationProbability >= thresholds.maximumPrecipitationProbability ||
      windGustKph >= thresholds.maximumWindGustKph ||
      weatherCode == 95 ||
      weatherCode == 96 ||
      weatherCode == 99;

  String safetyReason(RidingSafetyThresholds thresholds) {
    if (temperatureC <= thresholds.minimumTemperatureC) {
      return 'temperature below your outdoor limit';
    }
    if (temperatureC >= thresholds.maximumTemperatureC) {
      return 'temperature above your outdoor limit';
    }
    if (windGustKph >= thresholds.maximumWindGustKph) {
      return 'wind gusts above your outdoor limit';
    }
    if (weatherCode >= 95) return 'thunderstorm risk';
    return 'heavy or very likely precipitation';
  }
}
