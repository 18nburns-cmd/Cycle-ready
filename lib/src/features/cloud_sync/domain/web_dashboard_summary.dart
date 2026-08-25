import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';

class WebDashboardSummary {
  const WebDashboardSummary({
    required this.rideCount,
    required this.totalDistanceMetres,
    required this.totalDurationSeconds,
    required this.totalTrainingLoad,
    required this.ftp,
    required this.weightKg,
    required this.latestHrv,
    required this.updatedAt,
  });

  final int rideCount;
  final double totalDistanceMetres;
  final int totalDurationSeconds;
  final double totalTrainingLoad;
  final int? ftp;
  final double? weightKg;
  final double? latestHrv;
  final DateTime updatedAt;

  factory WebDashboardSummary.fromSnapshot(CloudSnapshot snapshot) {
    final activities = _rows(snapshot.payload, 'activities');
    final athlete = _rows(snapshot.payload, 'athleteSettings');
    final weights = _rows(snapshot.payload, 'bodyMeasurements')
      ..sort(
          (a, b) => _date(b['measuredAt']).compareTo(_date(a['measuredAt'])));
    final recovery = _rows(snapshot.payload, 'dailyRecovery')
      ..sort((a, b) => _date(b['day']).compareTo(_date(a['day'])));
    return WebDashboardSummary(
      rideCount: activities.length,
      totalDistanceMetres: activities.fold(
        0,
        (sum, row) => sum + _number(row['distanceMetres']),
      ),
      totalDurationSeconds: activities.fold(
        0,
        (sum, row) => sum + _number(row['durationSeconds']).round(),
      ),
      totalTrainingLoad: activities.fold(
        0,
        (sum, row) => sum + _number(row['trainingLoad']),
      ),
      ftp: athlete.isEmpty
          ? null
          : _nullableNumber(athlete.first['ftp'])?.round(),
      weightKg:
          weights.isEmpty ? null : _nullableNumber(weights.first['weightKg']),
      latestHrv: recovery.isEmpty
          ? null
          : _nullableNumber(recovery.first['hrvMilliseconds']),
      updatedAt: snapshot.updatedAt,
    );
  }
}

List<Map<String, Object?>> _rows(
  Map<String, Object?> payload,
  String key,
) {
  final value = payload[key];
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry('$key', value)))
      .toList();
}

double _number(Object? value) => _nullableNumber(value) ?? 0;

double? _nullableNumber(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };

DateTime _date(Object? value) =>
    value is DateTime ? value : DateTime.tryParse('$value') ?? DateTime(1970);
