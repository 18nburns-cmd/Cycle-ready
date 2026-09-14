import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_reconciliation.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:flutter/material.dart';

class WorkoutDeliveryStatusBanner extends StatelessWidget {
  const WorkoutDeliveryStatusBanner({
    required this.deliveryStatus,
    required this.reconciliationStatus,
    this.onRetry,
    super.key,
  });

  final WorkoutDeliveryStatus? deliveryStatus;
  final WorkoutReconciliationStatus? reconciliationStatus;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail) =
        switch ((deliveryStatus, reconciliationStatus)) {
      (WorkoutDeliveryStatus.failed, _) => (
          Icons.sync_problem,
          'Workout delivery failed',
          'CycleReady could not update Intervals.icu. You can retry safely.',
        ),
      (_, WorkoutReconciliationStatus.externallyDiverged) ||
      (WorkoutDeliveryStatus.externallyDiverged, _) =>
        (
          Icons.compare_arrows,
          'Changed in Intervals.icu',
          'The provider workout differs from the CycleReady prescription.',
        ),
      (_, WorkoutReconciliationStatus.missing) => (
          Icons.cloud_off_outlined,
          'Missing from Intervals.icu',
          'This planned workout is not currently available on the provider.',
        ),
      (WorkoutDeliveryStatus.pending, _) => (
          Icons.cloud_upload_outlined,
          'Waiting to sync',
          'CycleReady has queued this workout for delivery.',
        ),
      _ => (null, '', ''),
    };
    if (icon == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(detail),
          ],
        )),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
      ]),
    );
  }
}
