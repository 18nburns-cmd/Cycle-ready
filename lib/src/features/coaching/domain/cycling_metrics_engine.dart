import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';

class CyclingMetricsSnapshot {
  const CyclingMetricsSnapshot({
    required this.values,
    required this.latestRide,
  });

  final Map<String, Object?> values;
  final Map<String, Object?>? latestRide;

  Map<String, Object?> toJson() => {
        'metrics': _withoutNulls(values),
        if (latestRide != null) 'latestRide': _withoutNulls(latestRide!),
      };
}

class CyclingMetricsEngine {
  const CyclingMetricsEngine();

  CyclingMetricsSnapshot calculate({
    required List<Activity> activities,
    required AthleteSetting? athlete,
    required TrainingMetrics training,
    required RecoveryInput recovery,
    required List<BodyMetric> body,
    required List<FtpEstimate> ftpHistory,
    required DateTime now,
  }) {
    final ftp = athlete?.ftp;
    final weight = body.isNotEmpty ? body.last.weightKg : athlete?.weightKg;
    final last7 = activities.where(
      (a) => !a.startedAt.isBefore(now.subtract(const Duration(days: 7))),
    );
    final last28 = activities.where(
      (a) => !a.startedAt.isBefore(now.subtract(const Duration(days: 28))),
    );
    final hardSessions = last7.where((a) {
      final load = a.trainingLoad ?? 0;
      final intensity = ftp != null && a.normalisedPower != null
          ? a.normalisedPower! / ftp
          : 0;
      return load >= 70 || intensity >= .9;
    }).length;
    final latest = activities.isEmpty
        ? null
        : ([...activities]..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
            .first;
    final acceptedFtp = ftpHistory.where((item) => item.accepted).toList()
      ..sort((a, b) => a.estimatedAt.compareTo(b.estimatedAt));
    final ftpTrend = acceptedFtp.length < 2
        ? null
        : _trend(
            acceptedFtp.first.watts.toDouble(),
            acceptedFtp.last.watts.toDouble(),
          );
    final weightTrend = body.length < 2
        ? null
        : _trend(body.first.weightKg, body.last.weightKg, tolerance: .01);
    final load28 = last28.fold<double>(
      0,
      (sum, a) => sum + (a.trainingLoad?.toDouble() ?? 0),
    );
    final powerZones = ftp == null
        ? null
        : {
            'z1RecoveryMax': (ftp * .55).round(),
            'z2EnduranceMax': (ftp * .75).round(),
            'z3TempoMax': (ftp * .90).round(),
            'z4ThresholdMax': (ftp * 1.05).round(),
            'z5Vo2Max': (ftp * 1.20).round(),
          };
    final maxHr = athlete?.maximumHeartRate;
    final restingHr = athlete?.restingHeartRate;
    final hrZones = maxHr == null || restingHr == null
        ? null
        : {
            for (var zone = 1; zone <= 5; zone++)
              'z$zone':
                  (restingHr + (maxHr - restingHr) * (.5 + (zone - 1) * .1))
                      .round(),
          };
    return CyclingMetricsSnapshot(
      values: {
        'ftpWatts': _measured(ftp),
        'wattsPerKg': ftp == null || weight == null || weight <= 0
            ? null
            : _calculated(ftp / weight),
        'powerZonesWatts': powerZones == null ? null : _calculated(powerZones),
        'heartRateZoneStartsBpm': hrZones == null ? null : _calculated(hrZones),
        'trainingHours7Days': _calculated(
          last7.fold<int>(0, (sum, a) => sum + a.durationSeconds) / 3600,
        ),
        'distanceKm7Days': _calculated(
          last7.fold<double>(0, (sum, a) => sum + a.distanceMetres) / 1000,
        ),
        'load7Days': _calculated(training.weeklyLoad),
        'load28Days': _calculated(load28),
        'load28DayWeeklyAverage': _calculated(load28 / 4),
        'fitness': _calculated(training.fitness),
        'fatigue': _calculated(training.fatigue),
        'form': _calculated(training.form),
        'acuteChronicRatio': training.fitness <= 0
            ? null
            : _calculated(training.fatigue / training.fitness),
        'fitnessTrend': _trendLabel(training.rampRate),
        'hardSessionsLast7Days': _calculated(hardSessions),
        'restingHeartRateBpm': recovery.hasHealthData
            ? _measured(recovery.restingHeartRate)
            : null,
        'restingHeartRateBaselineBpm': recovery.hasHealthData
            ? _calculated(recovery.baselineRestingHeartRate)
            : null,
        'hrvMs': recovery.hasHealthData && recovery.hrvMilliseconds != null
            ? _measured(recovery.hrvMilliseconds)
            : null,
        'hrvBaselineMs':
            recovery.hasHealthData && recovery.baselineHrvMilliseconds != null
                ? _calculated(recovery.baselineHrvMilliseconds)
                : null,
        'sleepHours': recovery.hasHealthData
            ? _measured(recovery.sleepMinutes / 60)
            : null,
        'weightKg': weight == null ? null : _measured(weight),
        'weightTrend': weightTrend,
        'ftpTrend': ftpTrend,
      },
      latestRide: latest == null ? null : _ride(latest, ftp),
    );
  }

  Map<String, Object?> _ride(Activity ride, int? ftp) {
    final np = ride.normalisedPower;
    final intensity = ftp == null || np == null || ftp <= 0 ? null : np / ftp;
    return {
      'id': ride.id,
      'title': ride.title,
      'startedAt': ride.startedAt.toIso8601String(),
      'durationMinutes': _measured(ride.durationSeconds / 60),
      'distanceKm': _measured(ride.distanceMetres / 1000),
      'elevationMetres': _measured(ride.elevationMetres),
      'averageHeartRateBpm': _measured(ride.averageHeartRate),
      'maximumHeartRateBpm': _measured(ride.maximumHeartRate),
      'averagePowerWatts': _measured(ride.averagePower),
      'normalisedPowerWatts': _calculated(ride.normalisedPower),
      'intensityFactor': intensity == null ? null : _calculated(intensity),
      'trainingLoad': _calculated(ride.trainingLoad),
      'averageCadenceRpm': _measured(ride.averageCadence),
      'calories': _calculated(ride.calories),
    };
  }
}

Map<String, Object?>? _measured(Object? value) =>
    value == null ? null : {'label': 'MEASURED', 'value': value};
Map<String, Object?>? _calculated(Object? value) =>
    value == null ? null : {'label': 'CALCULATED', 'value': value};
Map<String, Object?> _trendLabel(double value) => {
      'label': 'TREND',
      'value': value > 1
          ? 'increasing'
          : value < -1
              ? 'decreasing'
              : 'stable',
    };
Map<String, Object?> _trend(double first, double last,
    {double tolerance = .02}) {
  final change = first == 0 ? 0 : (last - first) / first;
  return {
    'label': 'TREND',
    'value': change > tolerance
        ? 'increasing'
        : change < -tolerance
            ? 'decreasing'
            : 'stable',
  };
}

Map<String, Object?> _withoutNulls(Map<String, Object?> input) => {
      for (final entry in input.entries)
        if (entry.value != null) entry.key: entry.value,
    };
