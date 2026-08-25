import 'dart:math' as math;

const powerCurveDurations = [
  5,
  15,
  30,
  60,
  180,
  300,
  600,
  1200,
  1800,
  3600,
];

class PowerCurvePoint {
  const PowerCurvePoint({
    required this.seconds,
    required this.watts,
    required this.achievedAt,
    required this.activityId,
  });

  final int seconds;
  final int watts;
  final DateTime achievedAt;
  final String activityId;
}

typedef PowerCurveRideInput = ({
  String activityId,
  DateTime date,
  int durationSeconds,
  Iterable<({int elapsedSeconds, int watts})> samples,
});

List<PowerCurvePoint> calculatePowerCurve(
  Iterable<PowerCurveRideInput> rides,
) {
  final best = <int, PowerCurvePoint>{};
  for (final ride in rides) {
    final series = List<int?>.filled(ride.durationSeconds + 1, null);
    for (final sample in ride.samples) {
      if (sample.elapsedSeconds >= 0 &&
          sample.elapsedSeconds < series.length &&
          sample.watts >= 0 &&
          sample.watts <= 2500) {
        series[sample.elapsedSeconds] = sample.watts;
      }
    }
    for (final duration in powerCurveDurations) {
      final watts = _bestAverage(series, duration);
      if (watts == null || watts <= (best[duration]?.watts ?? 0)) continue;
      best[duration] = PowerCurvePoint(
        seconds: duration,
        watts: watts,
        achievedAt: ride.date,
        activityId: ride.activityId,
      );
    }
  }
  return [
    for (final duration in powerCurveDurations)
      if (best[duration] != null) best[duration]!,
  ];
}

int? _bestAverage(List<int?> values, int duration) {
  if (values.length < duration) return null;
  var sum = 0;
  var available = 0;
  double? best;
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value != null) {
      sum += value;
      available++;
    }
    if (index >= duration) {
      final removed = values[index - duration];
      if (removed != null) {
        sum -= removed;
        available--;
      }
    }
    if (index >= duration - 1 && available >= duration * .9) {
      best = math.max(best ?? 0, sum / available);
    }
  }
  return best?.round();
}

String powerDurationLabel(int seconds) => switch (seconds) {
      < 60 => '${seconds}s',
      60 => '1m',
      180 => '3m',
      300 => '5m',
      600 => '10m',
      1200 => '20m',
      1800 => '30m',
      3600 => '60m',
      _ => '${seconds ~/ 60}m',
    };
