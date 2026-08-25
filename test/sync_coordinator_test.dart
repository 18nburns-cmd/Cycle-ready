import 'package:cycle_ready/src/features/sync/application/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic sync runs initially and after the throttle interval', () {
    final now = DateTime(2026, 7, 31, 12);
    expect(automaticSyncIsDue(null, now), isTrue);
    expect(
      automaticSyncIsDue(now.subtract(const Duration(minutes: 9)), now),
      isFalse,
    );
    expect(
      automaticSyncIsDue(now.subtract(const Duration(minutes: 10)), now),
      isTrue,
    );
  });

  test('failed syncs use bounded exponential retry delays', () {
    expect(syncRetryDelay(1), const Duration(minutes: 2));
    expect(syncRetryDelay(2), const Duration(minutes: 5));
    expect(syncRetryDelay(3), const Duration(minutes: 15));
    expect(syncRetryDelay(4), const Duration(minutes: 30));
    expect(syncRetryDelay(5), const Duration(hours: 1));
    expect(syncRetryDelay(20), const Duration(hours: 1));
  });

  test('persisted retry prevents an early sync after app restart', () {
    final now = DateTime(2026, 8, 25, 12);
    expect(
      automaticSyncIsDue(
        null,
        now,
        nextRetryAt: now.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    expect(
      automaticSyncIsDue(
        null,
        now,
        nextRetryAt: now.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });
}
