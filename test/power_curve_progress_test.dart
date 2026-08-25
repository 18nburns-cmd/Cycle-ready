import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve_progress.dart';
import 'package:flutter_test/flutter_test.dart';

PowerCurveRideInput ride(String id, DateTime date, int watts) => (
      activityId: id,
      date: date,
      durationSeconds: 1300,
      samples: [
        for (var second = 0; second <= 1300; second++)
          (elapsedSeconds: second, watts: watts),
      ],
    );

void main() {
  test('compares the latest 28 days with the preceding 28 days', () {
    final now = DateTime(2026, 8, 15);
    final result = calculatePowerCurveProgress([
      ride('previous', now.subtract(const Duration(days: 40)), 200),
      ride('current', now.subtract(const Duration(days: 10)), 220),
    ], now: now);

    expect(result.map((item) => item.seconds), [60, 300, 1200]);
    expect(result.first.changeWatts, 20);
    expect(result.first.changePercent, closeTo(10, .01));
  });

  test('does not compare when the previous period has no matching data', () {
    final now = DateTime(2026, 8, 15);
    final result = calculatePowerCurveProgress([
      ride('current', now.subtract(const Duration(days: 10)), 220),
    ], now: now);
    expect(result, isEmpty);
  });
}
