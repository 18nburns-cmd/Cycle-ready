import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cycle_ready/src/features/intervals/domain/intervals_wellness.dart';
import 'package:cycle_ready/src/features/intervals/domain/intervals_workout.dart';

bool isRestrictedIntervalsActivity(Map<String, dynamic> activity) {
  final note = '${activity['_note'] ?? ''}'.toLowerCase();
  final source = '${activity['source'] ?? ''}'.toUpperCase();
  final type = activity['type'];
  final duration = activity['moving_time'];
  return note.contains('not available via the api') ||
      (source == 'STRAVA' && type == null && duration == null);
}

final intervalsIcuServiceProvider = Provider((ref) => IntervalsIcuService());

class IntervalsCredentials {
  const IntervalsCredentials(this.athleteId, this.apiKey);
  final String athleteId;
  final String apiKey;
}

class IntervalsActivity {
  const IntervalsActivity({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMetres,
    required this.elevationMetres,
    this.averageHeartRate,
    this.maximumHeartRate,
    this.averagePower,
    this.normalisedPower,
    this.averageCadence,
    this.trainingLoad,
    this.calories,
  });
  final String id;
  final String name;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final double elevationMetres;
  final int? averageHeartRate;
  final int? maximumHeartRate;
  final int? averagePower;
  final int? normalisedPower;
  final int? averageCadence;
  final int? trainingLoad;
  final int? calories;
}

class IntervalsPowerSample {
  const IntervalsPowerSample(this.elapsedSeconds, this.watts);
  final int elapsedSeconds;
  final int watts;
}

class IntervalsActivitySample {
  const IntervalsActivitySample({
    required this.elapsedSeconds,
    this.watts,
    this.heartRate,
    this.cadence,
    this.altitudeMetres,
    this.distanceMetres,
    this.latitude,
    this.longitude,
  });

  final int elapsedSeconds;
  final int? watts;
  final int? heartRate;
  final int? cadence;
  final double? altitudeMetres;
  final double? distanceMetres;
  final double? latitude;
  final double? longitude;
}

List<IntervalsActivitySample> parseIntervalsActivityStreams(Object? decoded) {
  if (decoded is! List) return const [];
  final streams = <String, List<dynamic>>{};
  List<dynamic>? longitudes;
  for (final item in decoded.whereType<Map<String, dynamic>>()) {
    final type = '${item['type']}';
    if (item['data'] is List) {
      streams[type] = item['data'] as List<dynamic>;
    }
    if (type == 'latlng' && item['data2'] is List) {
      longitudes = item['data2'] as List<dynamic>;
    }
  }
  final length = [
    ...streams.values.map((values) => values.length),
    longitudes?.length ?? 0,
  ].fold<int>(0, math.max);
  if (length == 0) return const [];
  num? at(String type, int index) {
    final values = streams[type];
    if (values == null || index >= values.length) return null;
    return values[index] as num?;
  }

  return List.generate(length, (index) {
    final seconds = at('time', index)?.round() ?? index;
    final double? longitude = longitudes != null && index < longitudes.length
        ? (longitudes[index] as num?)?.toDouble()
        : null;
    return IntervalsActivitySample(
      elapsedSeconds: seconds,
      watts: at('watts', index)?.round(),
      heartRate: at('heartrate', index)?.round(),
      cadence: at('cadence', index)?.round(),
      altitudeMetres: at('altitude', index)?.toDouble(),
      distanceMetres: at('distance', index)?.toDouble(),
      latitude: at('latlng', index)?.toDouble(),
      longitude: longitude,
    );
  }).where((sample) {
    return sample.watts != null ||
        sample.heartRate != null ||
        sample.cadence != null ||
        sample.altitudeMetres != null ||
        sample.distanceMetres != null ||
        (sample.latitude != null && sample.longitude != null);
  }).toList();
}

class IntervalsIcuService {
  IntervalsIcuService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _client;
  static const _athleteKey = 'intervals_athlete_id';
  static const _apiKey = 'intervals_api_key';

  int _lastRestrictedActivityCount = 0;

  /// Activities visible in Intervals.icu whose underlying data the API did
  /// not expose (most commonly activities sourced from Strava).
  int get lastRestrictedActivityCount => _lastRestrictedActivityCount;

  Future<void> saveCredentials(IntervalsCredentials value) async {
    await _storage.write(key: _athleteKey, value: value.athleteId.trim());
    await _storage.write(key: _apiKey, value: value.apiKey.trim());
  }

  Future<IntervalsCredentials?> credentials() async {
    final athlete = await _storage.read(key: _athleteKey);
    final key = await _storage.read(key: _apiKey);
    return athlete == null || key == null
        ? null
        : IntervalsCredentials(athlete, key);
  }

  Future<bool> testConnection(IntervalsCredentials credentials) async {
    final token = base64Encode(utf8.encode('API_KEY:${credentials.apiKey}'));
    final response = await _client.get(
      Uri.parse(
        'https://intervals.icu/api/v1/athlete/${credentials.athleteId}',
      ),
      headers: {'Authorization': 'Basic $token'},
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<List<IntervalsActivity>> fetchRecentActivities() async {
    final value = await credentials();
    if (value == null) throw StateError('Intervals.icu is not connected.');
    final oldest = DateTime.now().subtract(const Duration(days: 180));
    final date =
        '${oldest.year}-${oldest.month.toString().padLeft(2, '0')}-${oldest.day.toString().padLeft(2, '0')}';
    final fields = [
      'id',
      'source',
      '_note',
      'name',
      'type',
      'start_date_local',
      'moving_time',
      'distance',
      'total_elevation_gain',
      'average_heartrate',
      'max_heartrate',
      'average_watts',
      'icu_average_watts',
      'icu_normalized_watts',
      'average_cadence',
      'icu_training_load',
      'calories',
    ].join(',');
    final response = await _client.get(
      Uri.parse(
              'https://intervals.icu/api/v1/athlete/${value.athleteId}/activities')
          .replace(queryParameters: {'oldest': date, 'fields': fields}),
      headers: _headers(value),
    );
    if (response.statusCode != 200) {
      throw StateError('Intervals.icu returned ${response.statusCode}.');
    }
    final json = jsonDecode(response.body) as List<dynamic>;
    _lastRestrictedActivityCount = json.where((item) {
      return item is Map<String, dynamic> &&
          isRestrictedIntervalsActivity(item);
    }).length;
    final activities = json.where((item) {
      final type = '${(item as Map<String, dynamic>)['type']}'.toLowerCase();
      return type.contains('ride') || type.contains('cycling');
    }).map((item) {
      final map = item as Map<String, dynamic>;
      int? integer(String key) => (map[key] as num?)?.round();
      double number(String key) => (map[key] as num?)?.toDouble() ?? 0;
      return IntervalsActivity(
        id: '${map['id']}',
        name: '${map['name'] ?? 'Cycling'}',
        startedAt: DateTime.parse('${map['start_date_local']}'),
        durationSeconds: integer('moving_time') ?? 0,
        distanceMetres: number('distance'),
        elevationMetres: number('total_elevation_gain'),
        averageHeartRate: integer('average_heartrate'),
        maximumHeartRate: integer('max_heartrate'),
        averagePower: integer('icu_average_watts') ?? integer('average_watts'),
        normalisedPower: integer('icu_normalized_watts') ??
            integer('icu_weighted_avg_watts') ??
            integer('weighted_average_watts'),
        averageCadence: integer('average_cadence'),
        trainingLoad: integer('icu_training_load'),
        calories: integer('calories'),
      );
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return activities;
  }

  Future<List<IntervalsWellness>> fetchWellness() async {
    final value = await credentials();
    if (value == null) throw StateError('Intervals.icu is not connected.');
    final now = DateTime.now();
    final oldest = now.subtract(const Duration(days: 35));
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await _client.get(
      Uri.parse(
              'https://intervals.icu/api/v1/athlete/${value.athleteId}/wellness')
          .replace(queryParameters: {
        'oldest': date(oldest),
        'newest': date(now),
      }),
      headers: _headers(value),
    );
    if (response.statusCode != 200) {
      throw StateError(
          'Intervals.icu wellness returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().map((map) {
      double? number(String key) => (map[key] as num?)?.toDouble();
      return IntervalsWellness(
        day: DateTime.parse('${map['id']}'),
        restingHeartRate: number('restingHR'),
        averageSleepingHeartRate: number('avgSleepingHR'),
        hrvRmssd: number('hrv'),
        hrvSdnn: number('hrvSDNN'),
      );
    }).toList();
  }

  Future<int> publishPlannedWorkouts(
      List<IntervalsPlannedWorkout> workouts) async {
    if (workouts.isEmpty) return 0;
    final value = await credentials();
    if (value == null) throw StateError('Intervals.icu is not connected.');
    String localDate(DateTime day) =>
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}T00:00:00';
    final body = workouts
        .map((workout) => {
              'category': 'WORKOUT',
              'type': 'Ride',
              'start_date_local': localDate(workout.day),
              'name': workout.name,
              'description': workout.description,
              'planned_duration': workout.durationSeconds,
              'target': 'POWER',
              'external_id': workout.externalId,
            })
        .toList();
    final response = await _client.post(
      Uri.parse(
              'https://intervals.icu/api/v1/athlete/${value.athleteId}/events/bulk')
          .replace(queryParameters: {'upsert': 'true'}),
      headers: {
        ..._headers(value),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Intervals.icu calendar returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    return decoded is List ? decoded.length : workouts.length;
  }

  Future<List<IntervalsPowerSample>> fetchPowerSamples(
      String activityId) async {
    final samples = await fetchActivitySamples(activityId);
    return samples
        .where((sample) => sample.watts != null)
        .map((sample) =>
            IntervalsPowerSample(sample.elapsedSeconds, sample.watts!))
        .toList();
  }

  Future<List<IntervalsActivitySample>> fetchActivitySamples(
      String activityId) async {
    final value = await credentials();
    if (value == null) return const [];
    final response = await _client.get(
      Uri.parse(
        'https://intervals.icu/api/v1/activity/$activityId/streams.json',
      ).replace(queryParameters: {
        'types': 'time,watts,heartrate,cadence,altitude,distance,latlng'
      }),
      headers: _headers(value),
    );
    if (response.statusCode != 200) {
      throw StateError(
          'Intervals.icu activity streams returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    return parseIntervalsActivityStreams(decoded);
  }

  Map<String, String> _headers(IntervalsCredentials value) {
    final token = base64Encode(utf8.encode('API_KEY:${value.apiKey}'));
    return {'Authorization': 'Basic $token'};
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _athleteKey);
    await _storage.delete(key: _apiKey);
  }
}
