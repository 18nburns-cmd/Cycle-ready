import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';

class PowerCurveProgress {
  const PowerCurveProgress({
    required this.seconds,
    required this.currentWatts,
    required this.previousWatts,
  });

  final int seconds;
  final int currentWatts;
  final int previousWatts;

  int get changeWatts => currentWatts - previousWatts;
  double get changePercent => changeWatts / previousWatts * 100;
}

List<PowerCurveProgress> calculatePowerCurveProgress(
  Iterable<PowerCurveRideInput> rides, {
  required DateTime now,
}) {
  const durations = {60, 300, 1200};
  final boundary = now.subtract(const Duration(days: 28));
  final oldest = now.subtract(const Duration(days: 56));
  final current = calculatePowerCurve(
    rides.where((ride) => !ride.date.isBefore(boundary)),
  );
  final previous = calculatePowerCurve(
    rides.where(
      (ride) => ride.date.isBefore(boundary) && !ride.date.isBefore(oldest),
    ),
  );

  return [
    for (final duration in durations)
      if (current.any((point) => point.seconds == duration) &&
          previous.any((point) => point.seconds == duration))
        PowerCurveProgress(
          seconds: duration,
          currentWatts:
              current.firstWhere((point) => point.seconds == duration).watts,
          previousWatts:
              previous.firstWhere((point) => point.seconds == duration).watts,
        ),
  ];
}
