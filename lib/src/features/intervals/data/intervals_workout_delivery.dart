import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_reconciliation.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/intervals/domain/intervals_workout.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IntervalsWorkoutDeliveryProvider
    implements WorkoutDeliveryProvider, ReconcilingWorkoutDeliveryProvider {
  const IntervalsWorkoutDeliveryProvider(
    this.service, {
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final IntervalsIcuService service;
  final FlutterSecureStorage _storage;
  static const _fingerprintKey = 'intervalsPublishedPlanFingerprintV1';

  @override
  String get id => 'intervals_icu';

  @override
  Future<WorkoutDeliveryResult> deliver(
    List<StructuredWorkout> workouts,
  ) async {
    final count = await service.publishPlannedWorkouts(_map(workouts));
    return WorkoutDeliveryResult(provider: id, delivered: count);
  }

  @override
  Future<WorkoutDeliveryResult> reconcile(
    List<StructuredWorkout> workouts, {
    required List<String> ownedExternalIds,
    bool force = false,
  }) async {
    final planned = _map(workouts);
    final fingerprint = _planFingerprint(planned, ownedExternalIds);
    var comparison = const <WorkoutReconciliationResult>[];
    if (!force &&
        planned.isNotEmpty &&
        await _storage.read(key: _fingerprintKey) == fingerprint) {
      final remote = await service.fetchPlannedWorkouts(
        oldest: workouts.map((item) => item.scheduledDay).reduce(
              (a, b) => a.isBefore(b) ? a : b,
            ),
        newest: workouts.map((item) => item.scheduledDay).reduce(
              (a, b) => a.isAfter(b) ? a : b,
            ),
      );
      comparison = reconcileWorkoutCalendar(
        expected: planned.map((item) => ProviderWorkoutSnapshot(
              externalId: item.externalId,
              contentHash: intervalsWorkoutContentHash(item),
            )),
        observed: remote.map((item) => ProviderWorkoutSnapshot(
              externalId: item.workout.externalId,
              contentHash: intervalsWorkoutContentHash(item.workout),
              providerWorkoutId: item.providerId,
            )),
      );
      if (comparison.every(
        (item) => item.status == WorkoutReconciliationStatus.current,
      )) {
        return WorkoutDeliveryResult(
          provider: id,
          delivered: 0,
          reconciliation: comparison,
        );
      }
    }
    final count = await service.replacePlannedWorkouts(
      planned,
      ownedExternalIds: ownedExternalIds,
    );
    await _storage.write(key: _fingerprintKey, value: fingerprint);
    return WorkoutDeliveryResult(
      provider: id,
      delivered: count,
      reconciliation: comparison,
    );
  }

  List<IntervalsPlannedWorkout> _map(List<StructuredWorkout> workouts) =>
      workouts
          .map((workout) => IntervalsPlannedWorkout(
                externalId: workout.id,
                day: workout.scheduledDay,
                name: 'CycleReady - ${workout.title}',
                description: renderIntervalsWorkout(workout),
                durationSeconds: workout.durationSeconds,
              ))
          .toList();
}

String intervalsWorkoutContentHash(IntervalsPlannedWorkout workout) => sha256
    .convert(utf8.encode(jsonEncode({
      'external_id': workout.externalId,
      'day': _dateOnly(workout.day),
      'name': workout.name,
      'description': workout.description,
      'duration': workout.durationSeconds,
    })))
    .toString();

String _planFingerprint(
  List<IntervalsPlannedWorkout> workouts,
  List<String> ownedExternalIds,
) =>
    sha256
        .convert(utf8.encode(jsonEncode({
          'owned_external_ids': ownedExternalIds,
          'workout_hashes': workouts.map(intervalsWorkoutContentHash).toList(),
        })))
        .toString();

String _dateOnly(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

String renderIntervalsWorkout(StructuredWorkout workout) {
  final lines = <String>[];
  for (final step in workout.steps) {
    if (step.repetitions > 1) lines.add('${step.repetitions}x');
    final duration = _duration(step.durationSeconds);
    final target = step.powerLowPercent == step.powerHighPercent
        ? '${step.powerLowPercent}%'
        : '${step.powerLowPercent}-${step.powerHighPercent}%';
    lines.add('- $duration $target ${step.name}');
    if (step.repetitions > 1 && step.recoverySeconds > 0) {
      lines.add(
        '- ${_duration(step.recoverySeconds)} ${step.recoveryPowerPercent}% Recovery',
      );
    }
    lines.add('');
  }
  return lines.join('\n').trim();
}

String _duration(int seconds) =>
    seconds % 60 == 0 ? '${seconds ~/ 60}m' : '${seconds}s';
