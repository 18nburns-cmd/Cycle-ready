import 'package:cycle_ready/src/features/health/domain/resting_heart_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses overnight samples and ignores daytime exercise', () {
    final now = DateTime(2026, 7, 27, 12);
    final result = estimateRestingHeartRate([
      TimedHeartRate(DateTime(2026, 7, 27, 2), 51),
      TimedHeartRate(DateTime(2026, 7, 27, 3), 49),
      TimedHeartRate(DateTime(2026, 7, 27, 4), 53),
      TimedHeartRate(DateTime(2026, 7, 27, 10), 160),
    ], now: now);

    expect(result, 49);
  });

  test('rejects implausible sensor values', () {
    final now = DateTime(2026, 7, 27, 12);
    final result = estimateRestingHeartRate([
      TimedHeartRate(DateTime(2026, 7, 27, 2), 0),
      TimedHeartRate(DateTime(2026, 7, 27, 3), 48),
    ], now: now);

    expect(result, 48);
  });
}
