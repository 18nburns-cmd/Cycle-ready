import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:cycle_ready/src/features/activities/domain/critical_power.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final powerRideInputsProvider =
    FutureProvider<List<PowerCurveRideInput>>((ref) async {
  // The activity stream can emit several times during one import. Reading a
  // snapshot prevents an expensive curve calculation being cancelled and
  // restarted for every intermediate database update. Sync explicitly
  // invalidates this provider after its transaction has completed.
  final rides = await ref.read(activitiesProvider.future);
  final repository = ref.read(activityRepositoryProvider);
  final oldest = DateTime.now().subtract(const Duration(days: 56));
  final inputs = <PowerCurveRideInput>[];
  for (final ride in rides.where((ride) => !ride.startedAt.isBefore(oldest))) {
    final samples = await repository.samplesFor(ride.id);
    final power = samples
        .where((sample) => sample.power != null)
        .map((sample) => (
              elapsedSeconds: sample.elapsedSeconds,
              watts: sample.power!,
            ))
        .toList();
    if (power.isEmpty) continue;
    inputs.add((
      activityId: ride.id,
      date: ride.startedAt,
      durationSeconds: ride.durationSeconds,
      samples: power,
    ));
  }
  return inputs;
});

final powerCurveProvider = FutureProvider<List<PowerCurvePoint>>((ref) async {
  final inputs = await ref.watch(powerRideInputsProvider.future);
  return calculatePowerCurve(inputs);
});

final powerCurveProgressProvider =
    FutureProvider<List<PowerCurveProgress>>((ref) async {
  final inputs = await ref.watch(powerRideInputsProvider.future);
  return calculatePowerCurveProgress(inputs, now: DateTime.now());
});

final criticalPowerProvider = Provider<CriticalPowerEstimate?>((ref) {
  final curve = ref.watch(powerCurveProvider).valueOrNull;
  return curve == null ? null : estimateCriticalPower(curve);
});
