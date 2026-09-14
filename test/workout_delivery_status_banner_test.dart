import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_reconciliation.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:cycle_ready/src/features/coaching/presentation/workout_delivery_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase
      in <(WorkoutDeliveryStatus?, WorkoutReconciliationStatus?, String)>[
    (WorkoutDeliveryStatus.failed, null, 'Workout delivery failed'),
    (null, WorkoutReconciliationStatus.missing, 'Missing from Intervals.icu'),
    (
      null,
      WorkoutReconciliationStatus.externallyDiverged,
      'Changed in Intervals.icu',
    ),
    (WorkoutDeliveryStatus.pending, null, 'Waiting to sync'),
  ]) {
    testWidgets('shows ${testCase.$3}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WorkoutDeliveryStatusBanner(
          deliveryStatus: testCase.$1,
          reconciliationStatus: testCase.$2,
        ),
      ));
      expect(find.text(testCase.$3), findsOneWidget);
    });
  }

  testWidgets('offers retry only when a retry callback is supplied',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: WorkoutDeliveryStatusBanner(
        deliveryStatus: WorkoutDeliveryStatus.failed,
        reconciliationStatus: null,
        onRetry: () => retried = true,
      ),
    ));

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
