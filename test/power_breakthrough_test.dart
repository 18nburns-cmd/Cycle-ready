import 'package:cycle_ready/src/features/activities/domain/power_breakthrough.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curve = [
    PowerCurvePoint(
      seconds: 5,
      watts: 800,
      achievedAt: DateTime(2026, 8, 1),
      activityId: 'current',
    ),
    PowerCurvePoint(
      seconds: 60,
      watts: 400,
      achievedAt: DateTime(2026, 8, 1),
      activityId: 'older',
    ),
    PowerCurvePoint(
      seconds: 300,
      watts: 300,
      achievedAt: DateTime(2026, 8, 1),
      activityId: 'current',
    ),
  ];

  test('does not claim breakthroughs while establishing a baseline', () {
    expect(
      detectPowerBreakthroughs(
        activityId: 'current',
        rollingCurve: curve,
        priorPowerRideCount: 2,
      ),
      isEmpty,
    );
  });

  test('only returns supported bests achieved by the selected ride', () {
    final result = detectPowerBreakthroughs(
      activityId: 'current',
      rollingCurve: curve,
      priorPowerRideCount: 3,
    );
    expect(result.map((item) => item.seconds), [5, 300]);
    expect(result.map((item) => item.watts), [800, 300]);
  });
}
