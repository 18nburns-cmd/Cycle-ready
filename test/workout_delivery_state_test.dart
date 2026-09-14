import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);

  test('covers every provider-neutral delivery state', () {
    expect(WorkoutDeliveryStatus.values.map((value) => value.name), {
      'pending',
      'delivered',
      'updated',
      'deleted',
      'failed',
      'externallyDiverged',
    });
  });

  test('delivery acknowledgement requires and retains provider identity', () {
    final hash = List.filled(64, 'a').join();
    final pending = WorkoutDeliveryState.pending(
      plannedSessionId: 'plan-1',
      provider: 'intervals-icu',
      now: now,
    );
    final delivered = pending.transitionTo(
      WorkoutDeliveryStatus.delivered,
      now: now.add(const Duration(seconds: 1)),
      externalWorkoutId: 'event-42',
      desiredContentHash: hash,
      acknowledgedContentHash: hash,
      acknowledgedVersion: 1,
      attemptCount: 1,
    );
    final updated = delivered.transitionTo(
      WorkoutDeliveryStatus.updated,
      now: now.add(const Duration(seconds: 2)),
    );

    expect(updated.externalWorkoutId, 'event-42');
    expect(updated.acknowledgedContentHash, hash);
    expect(updated.acknowledgedVersion, 1);
    expect(updated.attemptCount, 1);
    expect(updated.needsAttention, isFalse);
  });

  test('failure is explainable and retry returns to pending', () {
    final failed = WorkoutDeliveryState.pending(
      plannedSessionId: 'plan-1',
      provider: 'intervals-icu',
      now: now,
    ).transitionTo(
      WorkoutDeliveryStatus.failed,
      now: now,
      failureMessage: 'Provider timed out.',
    );

    expect(failed.canRetry, isTrue);
    expect(failed.needsAttention, isTrue);
    expect(
      failed.transitionTo(WorkoutDeliveryStatus.pending, now: now).status,
      WorkoutDeliveryStatus.pending,
    );
  });

  test('deleted delivery is terminal', () {
    final deleted = WorkoutDeliveryState.pending(
      plannedSessionId: 'plan-1',
      provider: 'intervals-icu',
      now: now,
    ).transitionTo(WorkoutDeliveryStatus.deleted, now: now);

    expect(
      () => deleted.transitionTo(WorkoutDeliveryStatus.pending, now: now),
      throwsStateError,
    );
  });
}
