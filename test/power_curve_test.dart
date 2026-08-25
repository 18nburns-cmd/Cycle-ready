import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('power curve keeps the best effort at each duration', () {
    final now = DateTime(2026, 7, 30);
    final curve = calculatePowerCurve([
      (
        activityId: 'steady',
        date: now,
        durationSeconds: 400,
        samples: [
          for (var second = 0; second <= 400; second++)
            (elapsedSeconds: second, watts: 200),
        ],
      ),
      (
        activityId: 'hard',
        date: now.subtract(const Duration(days: 1)),
        durationSeconds: 400,
        samples: [
          for (var second = 0; second <= 400; second++)
            (elapsedSeconds: second, watts: second < 60 ? 350 : 180),
        ],
      ),
    ]);

    expect(curve.firstWhere((point) => point.seconds == 5).watts, 350);
    expect(curve.firstWhere((point) => point.seconds == 60).watts, 350);
    expect(curve.firstWhere((point) => point.seconds == 300).watts, 214);
    expect(
      curve.firstWhere((point) => point.seconds == 60).activityId,
      'hard',
    );
  });
}
