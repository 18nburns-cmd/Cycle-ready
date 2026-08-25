import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:cycle_ready/src/features/health/domain/sleep_duration.dart';
import 'package:cycle_ready/src/features/health/domain/resting_heart_rate.dart';
import 'package:health/health.dart';

class HealthConnectRepository {
  HealthConnectRepository({Health? health}) : _health = health ?? Health();

  final Health _health;

  static const types = <HealthDataType>[
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.WORKOUT,
  ];

  Future<void> configure() => _health.configure();

  Future<List<HealthDataType>> grantedTypes() async {
    await configure();
    final granted = <HealthDataType>[];
    for (final type in types) {
      try {
        if (await _health.hasPermissions(
              [type],
              permissions: const [HealthDataAccess.READ],
            ) ??
            false) {
          granted.add(type);
        }
      } catch (_) {
        // One unsupported category must not disconnect all other categories.
      }
    }
    return granted;
  }

  Future<bool> requestPermissions() async {
    await configure();
    return _health.requestAuthorization(
      types,
      permissions: List.filled(types.length, HealthDataAccess.READ),
    );
  }

  Future<HealthSnapshot> readLatest(List<HealthDataType> grantedTypes) async {
    await configure();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final raw = await _health.getHealthDataFromTypes(
      types: grantedTypes,
      startTime: start,
      endTime: now,
    );
    final points = _health.removeDuplicates(raw);
    final allSleepPoints = points.where((point) => const {
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_SESSION,
        }.contains(point.type));
    final sleepMinutes = _latestSleepMinutes(allSleepPoints.toList());
    final sleepEndedAt = _latestSleepEnd(allSleepPoints.toList());
    final workouts = points.where((point) {
      final value = point.value;
      return point.type == HealthDataType.WORKOUT &&
          value is WorkoutHealthValue &&
          {
            HealthWorkoutActivityType.BIKING,
            HealthWorkoutActivityType.HAND_CYCLING,
          }.contains(value.workoutActivityType);
    }).map((point) {
      final value = point.value as WorkoutHealthValue;
      return ImportedWorkout(
        externalId: point.uuid,
        source: point.sourceName,
        startedAt: point.dateFrom,
        durationSeconds: point.dateTo.difference(point.dateFrom).inSeconds,
        distanceMetres: (value.totalDistance ?? 0).toDouble(),
        calories: value.totalEnergyBurned,
      );
    }).toList();

    final recordedResting =
        _latestNumeric(points, HealthDataType.RESTING_HEART_RATE);
    final estimatedResting = estimateRestingHeartRate(
      points
          .where((point) => point.type == HealthDataType.HEART_RATE)
          .map((point) => TimedHeartRate(
                point.dateFrom,
                _numeric(point) ?? 0,
              )),
      now: now,
    );
    final weightPoints = points
        .where((point) => point.type == HealthDataType.WEIGHT)
        .where((point) => _numeric(point) != null)
        .toList();
    final fatPoints = points
        .where((point) => point.type == HealthDataType.BODY_FAT_PERCENTAGE)
        .where((point) => _numeric(point) != null)
        .toList();
    final bodyMeasurements =
        _deduplicateBodyMeasurements(weightPoints.map((weight) {
      final nearestFat = fatPoints
          .where((fat) =>
              fat.dateFrom.difference(weight.dateFrom).abs() <
              const Duration(minutes: 5))
          .firstOrNull;
      return ImportedBodyMeasurement(
        measuredAt: weight.dateFrom,
        weightKg: _numeric(weight)!,
        bodyFatPercent: nearestFat == null ? null : _numeric(nearestFat),
        source: weight.sourceName,
      );
    }).toList());

    return HealthSnapshot(
      sleepMinutes: sleepMinutes == 0 ? null : sleepMinutes,
      sleepEndedAt: sleepEndedAt,
      restingHeartRate: recordedResting ?? estimatedResting,
      restingHeartRateEstimated:
          recordedResting == null && estimatedResting != null,
      hrvMilliseconds:
          _latestNumeric(points, HealthDataType.HEART_RATE_VARIABILITY_RMSSD),
      weightKg: _latestNumeric(points, HealthDataType.WEIGHT),
      bodyFatPercent:
          _latestNumeric(points, HealthDataType.BODY_FAT_PERCENTAGE),
      workoutCount: workouts.length,
      workouts: workouts,
      bodyMeasurements: bodyMeasurements,
      sources: points
          .map((point) => point.sourceName)
          .where((source) => source.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
      syncedAt: now,
    );
  }

  double? _latestNumeric(List<HealthDataPoint> points, HealthDataType type) {
    final matches = points.where((point) => point.type == type).toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (matches.isEmpty) return null;
    return _numeric(matches.first);
  }

  double? _numeric(HealthDataPoint point) {
    final value = point.value;
    return value is NumericHealthValue ? value.numericValue.toDouble() : null;
  }

  int _latestSleepMinutes(List<HealthDataPoint> points) {
    if (points.isEmpty) return 0;
    final sessions = points
        .where((point) => point.type == HealthDataType.SLEEP_SESSION)
        .toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));

    if (sessions.isNotEmpty) {
      final session = sessions.first;
      final stages = points.where((point) {
        return point.type != HealthDataType.SLEEP_SESSION &&
            point.dateTo.isAfter(session.dateFrom) &&
            point.dateFrom.isBefore(session.dateTo) &&
            point.sourceName == session.sourceName;
      }).toList();
      final chosen = stages.isEmpty ? [session] : stages;
      return uniqueSleepMinutes(
        chosen.map((point) => SleepInterval(
              point.dateFrom.isBefore(session.dateFrom)
                  ? session.dateFrom
                  : point.dateFrom,
              point.dateTo.isAfter(session.dateTo)
                  ? session.dateTo
                  : point.dateTo,
            )),
      );
    }

    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final latestEnd = points.first.dateTo;
    final nightStart = latestEnd.subtract(const Duration(hours: 16));
    return uniqueSleepMinutes(
      points
          .where((point) => point.dateTo.isAfter(nightStart))
          .map((point) => SleepInterval(point.dateFrom, point.dateTo)),
    );
  }

  DateTime? _latestSleepEnd(List<HealthDataPoint> points) {
    if (points.isEmpty) return null;
    return points
        .map((point) => point.dateTo)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<ImportedBodyMeasurement> _deduplicateBodyMeasurements(
    List<ImportedBodyMeasurement> values,
  ) {
    values.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final result = <ImportedBodyMeasurement>[];
    for (final value in values) {
      final duplicateIndex = result.lastIndexWhere(
        (existing) =>
            existing.measuredAt.difference(value.measuredAt).abs() <=
                const Duration(minutes: 2) &&
            (existing.weightKg - value.weightKg).abs() < .05,
      );
      if (duplicateIndex < 0) {
        result.add(value);
        continue;
      }
      final existing = result[duplicateIndex];
      result[duplicateIndex] = ImportedBodyMeasurement(
        measuredAt: existing.measuredAt.isAfter(value.measuredAt)
            ? existing.measuredAt
            : value.measuredAt,
        weightKg: value.weightKg,
        bodyFatPercent: value.bodyFatPercent ?? existing.bodyFatPercent,
        source: {
          ...existing.source.split(' + '),
          ...value.source.split(' + '),
        }.join(' + '),
      );
    }
    return result;
  }
}
