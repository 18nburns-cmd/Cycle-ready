import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve_progress.dart';
import 'package:flutter_test/flutter_test.dart';

PowerCurveProgress value(int seconds, int current, int previous) =>
    PowerCurveProgress(
      seconds: seconds,
      currentWatts: current,
      previousWatts: previous,
    );

void main() {
  test('requires at least one comparable duration', () {
    expect(assessPerformanceMomentum(const []), isNull);
  });

  test('identifies broad improvement', () {
    final result = assessPerformanceMomentum([
      value(60, 420, 400),
      value(300, 315, 300),
      value(1200, 251, 250),
    ]);
    expect(result?.status, PerformanceMomentumStatus.improving);
  });

  test('does not hide a mixed power profile behind an average', () {
    final result = assessPerformanceMomentum([
      value(60, 440, 400),
      value(300, 300, 300),
      value(1200, 225, 250),
    ]);
    expect(result?.status, PerformanceMomentumStatus.mixed);
  });

  test('treats small changes as normal stability', () {
    final result = assessPerformanceMomentum([
      value(60, 402, 400),
      value(300, 298, 300),
      value(1200, 251, 250),
    ]);
    expect(result?.status, PerformanceMomentumStatus.stable);
  });

  test('identifies a broad decline without claiming lost fitness', () {
    final result = assessPerformanceMomentum([
      value(60, 380, 400),
      value(300, 280, 300),
      value(1200, 249, 250),
    ]);
    expect(result?.status, PerformanceMomentumStatus.declining);
    expect(result?.explanation, contains('not necessarily lost fitness'));
  });
}
