import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/intervals/domain/intervals_wellness.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final intervalsWellnessAutoSyncProvider = FutureProvider<
    ({
      IntervalsHeartRateSummary heartRate,
      IntervalsHrvSummary? hrv
    })?>((ref) async {
  final service = ref.read(intervalsIcuServiceProvider);
  if (await service.credentials() == null) return null;
  final records = await service.fetchWellness();
  final summary = summariseIntervalsHeartRate(records);
  final hrv = summariseIntervalsHrv(records);
  if (summary != null) {
    await ref
        .read(recoveryControllerProvider.notifier)
        .applyIntervalsHeartRate(summary, hrv: hrv);
  }
  return summary == null ? null : (heartRate: summary, hrv: hrv);
});
