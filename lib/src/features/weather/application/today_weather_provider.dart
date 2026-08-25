import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/weather/data/cached_weather_repository.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayRideWeather {
  const TodayRideWeather({
    required this.location,
    required this.weather,
    required this.safetyProfile,
    required this.fetchedAt,
    required this.isCached,
  });

  final String location;
  final RideWeather weather;
  final RidingSafetyProfile safetyProfile;
  final DateTime fetchedAt;
  final bool isCached;

  RidingSafetyThresholds get thresholds =>
      RidingSafetyThresholds.forProfile(safetyProfile);
  bool get isUnsafe => weather.isUnsafe(thresholds);
  bool get isStale =>
      DateTime.now().difference(fetchedAt) > const Duration(hours: 6);
}

final todayRideWeatherProvider = FutureProvider<TodayRideWeather?>((ref) async {
  final athlete = await ref.watch(athleteProfileProvider.future);
  if (athlete.trainingLocation.trim().isEmpty) return null;
  final forecast = await ref.watch(weatherRepositoryProvider).forecast(
        location: athlete.trainingLocation,
        rideTimeMinutes: athlete.preferredRideTimeMinutes,
      );
  final now = DateTime.now();
  final weather = forecast.values[DateTime(now.year, now.month, now.day)];
  if (weather == null) return null;
  return TodayRideWeather(
    location: athlete.trainingLocation,
    weather: weather,
    safetyProfile: RidingSafetyProfile.values.firstWhere(
      (value) => value.name == athlete.ridingSafetyProfile,
      orElse: () => RidingSafetyProfile.balanced,
    ),
    fetchedAt: forecast.fetchedAt,
    isCached: forecast.isCached,
  );
});
