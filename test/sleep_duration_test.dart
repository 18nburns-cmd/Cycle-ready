import 'package:cycle_ready/src/features/health/domain/sleep_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlapping generic and staged sleep is counted once', () {
    final day = DateTime(2026, 7, 20);
    final total = uniqueSleepMinutes([
      SleepInterval(day, day.add(const Duration(hours: 8))),
      SleepInterval(day, day.add(const Duration(hours: 2))),
      SleepInterval(
          day.add(const Duration(hours: 2)), day.add(const Duration(hours: 6))),
      SleepInterval(
          day.add(const Duration(hours: 6)), day.add(const Duration(hours: 8))),
    ]);

    expect(total, 480);
  });

  test('separate sleep periods are both retained', () {
    final day = DateTime(2026, 7, 20);
    final total = uniqueSleepMinutes([
      SleepInterval(day, day.add(const Duration(hours: 7))),
      SleepInterval(day.add(const Duration(hours: 8)),
          day.add(const Duration(hours: 8, minutes: 30))),
    ]);

    expect(total, 450);
  });
}
