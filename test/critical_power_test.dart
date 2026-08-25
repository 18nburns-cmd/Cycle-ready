import 'package:cycle_ready/src/features/activities/domain/critical_power.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fits CP and W prime from a valid power-duration curve', () {
    const cp = 250;
    const wPrime = 20000;
    final estimate = estimateCriticalPower([
      for (final seconds in [180, 300, 600, 1200, 1800])
        PowerCurvePoint(
          seconds: seconds,
          watts: (cp + wPrime / seconds).round(),
          achievedAt: DateTime(2026, 8, 1),
          activityId: '$seconds',
        ),
    ]);
    expect(estimate, isNotNull);
    expect(estimate!.watts, closeTo(cp, 2));
    expect(estimate.wPrimeKilojoules, closeTo(20, .5));
    expect(estimate.confidence, CriticalPowerConfidence.high);
  });

  test('does not invent a model from insufficient durations', () {
    final estimate = estimateCriticalPower([
      PowerCurvePoint(
          seconds: 300,
          watts: 300,
          achievedAt: DateTime(2026),
          activityId: 'a'),
      PowerCurvePoint(
          seconds: 600,
          watts: 280,
          achievedAt: DateTime(2026),
          activityId: 'b'),
    ]);
    expect(estimate, isNull);
  });
}
