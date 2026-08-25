import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';

class WeatherForecast {
  const WeatherForecast({
    required this.values,
    required this.fetchedAt,
    this.isCached = false,
  });

  final Map<DateTime, RideWeather> values;
  final DateTime fetchedAt;
  final bool isCached;

  bool isStaleAt(DateTime now) =>
      now.difference(fetchedAt) > const Duration(hours: 6);
}

abstract interface class WeatherRepository {
  Future<WeatherForecast> forecast({
    required String location,
    required int rideTimeMinutes,
  });
}
