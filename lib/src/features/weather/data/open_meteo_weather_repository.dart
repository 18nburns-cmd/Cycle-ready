import 'dart:convert';

import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';
import 'package:cycle_ready/src/features/weather/domain/weather_repository.dart';
import 'package:http/http.dart' as http;

class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository({http.Client? client})
      : client = client ?? http.Client();

  final http.Client client;

  @override
  Future<WeatherForecast> forecast({
    required String location,
    required int rideTimeMinutes,
  }) async {
    if (location.trim().isEmpty) {
      return WeatherForecast(values: const {}, fetchedAt: DateTime.now());
    }
    final geocode = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': location.trim(),
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final placeResponse =
        await client.get(geocode).timeout(const Duration(seconds: 8));
    if (placeResponse.statusCode != 200) {
      throw StateError('Weather location lookup failed.');
    }
    final placeJson = jsonDecode(placeResponse.body) as Map<String, dynamic>;
    final results = placeJson['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw StateError('Weather location was not found.');
    }
    final place = results.first as Map<String, dynamic>;
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${place['latitude']}',
      'longitude': '${place['longitude']}',
      'hourly':
          'temperature_2m,precipitation_probability,precipitation,weather_code,wind_gusts_10m',
      'forecast_days': '14',
      'timezone': 'auto',
    });
    final response =
        await client.get(forecastUri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Weather forecast request failed.');
    }
    return WeatherForecast(
      values: _parse(
          jsonDecode(response.body) as Map<String, dynamic>, rideTimeMinutes),
      fetchedAt: DateTime.now(),
    );
  }

  Map<DateTime, RideWeather> _parse(
    Map<String, dynamic> json,
    int rideTimeMinutes,
  ) {
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const {};
    final times = hourly['time'] as List<dynamic>? ?? const [];
    final result = <DateTime, RideWeather>{};
    for (var index = 0; index < times.length; index++) {
      final at = DateTime.tryParse('${times[index]}');
      if (at == null || at.hour != rideTimeMinutes ~/ 60) continue;
      num value(String key) => (hourly[key] as List<dynamic>)[index] as num;
      result[DateTime(at.year, at.month, at.day)] = RideWeather(
        at: at,
        temperatureC: value('temperature_2m').toDouble(),
        precipitationMm: value('precipitation').toDouble(),
        precipitationProbability: value('precipitation_probability').round(),
        windGustKph: value('wind_gusts_10m').toDouble(),
        weatherCode: value('weather_code').round(),
      );
    }
    return result;
  }
}
