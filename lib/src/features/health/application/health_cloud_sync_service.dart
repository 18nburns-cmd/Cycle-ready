import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';

class HealthCloudSyncService {
  const HealthCloudSyncService(this.repository);

  final OfflineMutationRepository repository;

  Future<bool> enqueue(
    HealthSnapshot snapshot, {
    Future<bool> Function(ImportedWorkout workout)? includeWorkout,
  }) async {
    final hasWellness = snapshot.sleepMinutes != null ||
        snapshot.restingHeartRate != null ||
        snapshot.hrvMilliseconds != null ||
        snapshot.weightKg != null;
    if (!hasWellness && snapshot.workouts.isEmpty) {
      return false;
    }
    if (hasWellness) {
      await _enqueueWellness(snapshot);
    }
    for (final workout in snapshot.workouts) {
      if (includeWorkout != null && !await includeWorkout(workout)) continue;
      await _enqueueWorkout(workout, snapshot.syncedAt);
    }
    return true;
  }

  Future<void> _enqueueWellness(HealthSnapshot snapshot) async {
    if (snapshot.sleepMinutes == null &&
        snapshot.restingHeartRate == null &&
        snapshot.hrvMilliseconds == null &&
        snapshot.weightKg == null) {
      return;
    }
    final day = DateTime(
      snapshot.syncedAt.year,
      snapshot.syncedAt.month,
      snapshot.syncedAt.day,
    );
    final date = _date(day);
    final entityId = _stableUuid('health-connect:$date');
    await repository.enqueue(OfflineMutation(
      id: 'health-connect-wellness:$date',
      entityType: 'wellness_observation',
      entityId: entityId,
      operation: OfflineMutationOperation.upsert,
      payload: {
        'recorded_date': date,
        'hrv_ms': snapshot.hrvMilliseconds,
        'resting_hr': snapshot.restingHeartRate,
        'sleep_minutes': snapshot.sleepMinutes,
        'weight_kg': snapshot.weightKg,
        'source': 'health_connect',
        'source_payload': {
          'sleep_ended_at': snapshot.sleepEndedAt?.toUtc().toIso8601String(),
          'resting_hr_estimated': snapshot.restingHeartRateEstimated,
          'body_fat_percent': snapshot.bodyFatPercent,
          'providers': snapshot.sources,
          'synced_at': snapshot.syncedAt.toUtc().toIso8601String(),
        },
      },
      createdAt: snapshot.syncedAt.toUtc(),
    ));
  }

  Future<void> _enqueueWorkout(
    ImportedWorkout workout,
    DateTime syncedAt,
  ) async {
    final entityId = _stableUuid('health-connect:${workout.externalId}');
    await repository.enqueue(OfflineMutation(
      id: 'health-connect-activity:${workout.externalId}',
      entityType: 'activity',
      entityId: entityId,
      operation: OfflineMutationOperation.upsert,
      payload: {
        'external_activity_id': workout.externalId,
        'source': 'health_connect',
        'started_at': workout.startedAt.toUtc().toIso8601String(),
        'sport': 'cycling',
        'duration_seconds': workout.durationSeconds,
        'moving_time_seconds': workout.durationSeconds,
        'distance_metres': workout.distanceMetres,
        'source_payload': {
          'provider': workout.source,
          'calories': workout.calories,
          'synced_at': syncedAt.toUtc().toIso8601String(),
        },
      },
      createdAt: syncedAt.toUtc(),
    ));
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _stableUuid(String value) {
    final bytes = sha256.convert(utf8.encode(value)).bytes.toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .take(16)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
