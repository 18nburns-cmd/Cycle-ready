import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';

const breakthroughDurations = {5, 60, 300, 1200};

class PowerBreakthrough {
  const PowerBreakthrough({required this.seconds, required this.watts});

  final int seconds;
  final int watts;

  String get label => powerDurationLabel(seconds);
}

List<PowerBreakthrough> detectPowerBreakthroughs({
  required String activityId,
  required Iterable<PowerCurvePoint> rollingCurve,
  required int priorPowerRideCount,
}) {
  // Three earlier power rides are the minimum needed before using performance
  // language. Until then the curve is still establishing a baseline.
  if (priorPowerRideCount < 3) return const [];

  return rollingCurve
      .where((point) =>
          point.activityId == activityId &&
          breakthroughDurations.contains(point.seconds))
      .map((point) =>
          PowerBreakthrough(seconds: point.seconds, watts: point.watts))
      .toList()
    ..sort((a, b) => a.seconds.compareTo(b.seconds));
}
