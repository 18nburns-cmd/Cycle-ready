import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:cycle_ready/src/features/activities/domain/power_development_focus.dart';
import 'package:flutter_test/flutter_test.dart';

PowerCurvePoint point(int seconds, int watts) => PowerCurvePoint(
      seconds: seconds,
      watts: watts,
      achievedAt: DateTime(2026, 8, 20),
      activityId: '$seconds',
    );

void main() {
  test('withholds a limiter when the curve is too sparse', () {
    expect(
      identifyPowerDevelopmentFocus(
        curve: [point(5, 900), point(60, 360)],
        ftp: 200,
      ),
      isNull,
    );
  });

  test('finds the weakest area relative to a balanced profile', () {
    final focus = identifyPowerDevelopmentFocus(
      curve: [
        point(5, 900),
        point(60, 360),
        point(300, 190),
        point(1200, 200),
        point(3600, 165),
      ],
      ftp: 200,
    );
    expect(focus?.area, PowerDevelopmentArea.vo2Max);
    expect(focus?.comparisonCount, 5);
  });
}
