import 'package:cycle_ready/src/features/health/application/health_cloud_sync_service.dart';
import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues an idempotent relational wellness mutation', () async {
    final repository = _MemoryMutationRepository();
    final service = HealthCloudSyncService(repository);
    final syncedAt = DateTime(2026, 9, 3, 7, 30);

    expect(
      await service.enqueue(HealthSnapshot(
        sleepMinutes: 451,
        restingHeartRate: 48,
        hrvMilliseconds: 62,
        weightKg: 72.4,
        sources: const ['Samsung Health'],
        workouts: [
          ImportedWorkout(
            externalId: 'provider-ride-1',
            source: 'Samsung Health',
            startedAt: DateTime(2026, 9, 3, 6),
            durationSeconds: 3600,
            distanceMetres: 30000,
            calories: 650,
          ),
        ],
        syncedAt: syncedAt,
      )),
      isTrue,
    );
    final mutation = repository.values.first;
    expect(mutation.id, 'health-connect-wellness:2026-09-03');
    expect(mutation.entityType, 'wellness_observation');
    expect(mutation.entityId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(mutation.operation, OfflineMutationOperation.upsert);
    expect(mutation.payload['source'], 'health_connect');
    expect(mutation.payload['sleep_minutes'], 451);
    final activity = repository.values.last;
    expect(activity.entityType, 'activity');
    expect(activity.payload['external_activity_id'], 'provider-ride-1');
    expect(activity.payload['distance_metres'], 30000);
  });

  test('does not queue an empty Health Connect snapshot', () async {
    final repository = _MemoryMutationRepository();
    final queued = await HealthCloudSyncService(repository).enqueue(
      HealthSnapshot(syncedAt: DateTime(2026, 9, 3)),
    );
    expect(queued, isFalse);
    expect(repository.values, isEmpty);
  });
}

class _MemoryMutationRepository implements OfflineMutationRepository {
  final values = <OfflineMutation>[];

  @override
  Future<void> enqueue(OfflineMutation mutation) async {
    values.removeWhere((value) => value.id == mutation.id);
    values.add(mutation);
  }

  @override
  Future<List<OfflineMutation>> pending() async => values;

  @override
  Future<void> markApplied(String id) async {}

  @override
  Future<void> markConflict(String id, String reason) async {}

  @override
  Future<void> markRetry(String id, String reason) async {}
}
