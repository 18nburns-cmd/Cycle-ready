import 'dart:convert';

import 'package:cycle_ready/src/features/weather/data/open_meteo_weather_repository.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';
import 'package:cycle_ready/src/features/weather/domain/weather_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class WeatherCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureWeatherCacheStore implements WeatherCacheStore {
  const SecureWeatherCacheStore([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}

class CachedWeatherRepository implements WeatherRepository {
  const CachedWeatherRepository(
    this.remote,
    this.store, {
    this.now = DateTime.now,
  });

  final WeatherRepository remote;
  final WeatherCacheStore store;
  final DateTime Function() now;
  static const _maximumCacheAge = Duration(hours: 36);

  @override
  Future<WeatherForecast> forecast({
    required String location,
    required int rideTimeMinutes,
  }) async {
    final key = _key(location, rideTimeMinutes);
    try {
      final fresh = await remote.forecast(
        location: location,
        rideTimeMinutes: rideTimeMinutes,
      );
      if (fresh.values.isEmpty) {
        throw StateError('Weather service returned no forecast values.');
      }
      await store.write(key, _encode(fresh));
      return fresh;
    } catch (_) {
      final cached = _decode(await store.read(key));
      if (cached != null &&
          now().difference(cached.fetchedAt) <= _maximumCacheAge) {
        return WeatherForecast(
          values: cached.values,
          fetchedAt: cached.fetchedAt,
          isCached: true,
        );
      }
      rethrow;
    }
  }

  String _key(String location, int minutes) =>
      'weather_${location.trim().toLowerCase()}_$minutes';

  String _encode(WeatherForecast forecast) => jsonEncode({
        'fetchedAt': forecast.fetchedAt.toIso8601String(),
        'values': forecast.values.values
            .map((value) => {
                  'at': value.at.toIso8601String(),
                  'temperatureC': value.temperatureC,
                  'precipitationMm': value.precipitationMm,
                  'precipitationProbability': value.precipitationProbability,
                  'windGustKph': value.windGustKph,
                  'weatherCode': value.weatherCode,
                })
            .toList(),
      });

  WeatherForecast? _decode(String? source) {
    if (source == null) return null;
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse('${json['fetchedAt']}');
      final values = <DateTime, RideWeather>{};
      for (final item
          in (json['values'] as List).cast<Map<String, dynamic>>()) {
        final at = DateTime.parse('${item['at']}');
        values[DateTime(at.year, at.month, at.day)] = RideWeather(
          at: at,
          temperatureC: (item['temperatureC'] as num).toDouble(),
          precipitationMm: (item['precipitationMm'] as num).toDouble(),
          precipitationProbability:
              (item['precipitationProbability'] as num).round(),
          windGustKph: (item['windGustKph'] as num).toDouble(),
          weatherCode: (item['weatherCode'] as num).round(),
        );
      }
      return WeatherForecast(values: values, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => CachedWeatherRepository(
    OpenMeteoWeatherRepository(),
    const SecureWeatherCacheStore(),
  ),
);
