import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expected = [
    ProviderWorkoutSnapshot(externalId: 'cycle-1', contentHash: 'hash-a'),
    ProviderWorkoutSnapshot(externalId: 'cycle-2', contentHash: 'hash-b'),
    ProviderWorkoutSnapshot(externalId: 'cycle-3', contentHash: 'hash-c'),
  ];

  test('matches solely by stable external ID and content hash', () {
    final result =
        reconcileWorkoutCalendar(expected: expected, observed: const [
      ProviderWorkoutSnapshot(
        externalId: 'cycle-1',
        contentHash: 'hash-a',
        providerWorkoutId: '101',
      ),
      ProviderWorkoutSnapshot(
        externalId: 'cycle-2',
        contentHash: 'changed',
        providerWorkoutId: '102',
      ),
    ]);

    expect(result[0].status, WorkoutReconciliationStatus.current);
    expect(result[0].providerWorkoutId, '101');
    expect(result[1].status, WorkoutReconciliationStatus.externallyDiverged);
    expect(result[2].status, WorkoutReconciliationStatus.missing);
  });

  test('ignores provider entries not owned by CycleReady', () {
    final result =
        reconcileWorkoutCalendar(expected: expected, observed: const [
      ProviderWorkoutSnapshot(externalId: 'other-app', contentHash: 'hash-a'),
    ]);
    expect(result, hasLength(expected.length));
    expect(
        result.every(
            (item) => item.status == WorkoutReconciliationStatus.missing),
        isTrue);
  });
}
