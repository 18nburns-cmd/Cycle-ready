import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/offline_sync/data/drift_offline_mutation_repository.dart';
import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append mutations are idempotent and updates detect stale versions', () {
    final append = OfflineMutation(
      id: 'feedback:1',
      entityType: 'athlete_feedback',
      entityId: 'feedback-1',
      operation: OfflineMutationOperation.append,
      payload: const {},
      createdAt: DateTime.utc(2026, 8, 31),
    );
    expect(
      resolveMutationConflict(
        mutation: append,
        remoteVersion: null,
        remoteEntityExists: true,
      ),
      ConflictResolution.alreadyApplied,
    );

    final update = OfflineMutation(
      id: 'goal:1',
      entityType: 'goal',
      entityId: 'goal-1',
      operation: OfflineMutationOperation.upsert,
      payload: const {'name': 'A event'},
      baseVersion: '2026-08-30T12:00:00Z',
      createdAt: DateTime.utc(2026, 8, 31),
    );
    expect(
      resolveMutationConflict(
        mutation: update,
        remoteVersion: '2026-08-31T08:00:00Z',
        remoteEntityExists: true,
      ),
      ConflictResolution.conflict,
    );
  });

  test('Drift queue survives retries and removes applied rows from pending',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftOfflineMutationRepository(database);
    final mutation = OfflineMutation(
      id: 'wellness:2026-08-31',
      entityType: 'wellness_observation',
      entityId: 'wellness-1',
      operation: OfflineMutationOperation.upsert,
      payload: const {'source': 'manual', 'fatigue': 4},
      createdAt: DateTime.utc(2026, 8, 31, 7),
    );

    await repository.enqueue(mutation);
    expect((await repository.pending()).single.payload['fatigue'], 4);
    await repository.markRetry(mutation.id, 'offline');
    expect((await repository.pending()).single.attemptCount, 1);
    await repository.markApplied(mutation.id);
    expect(await repository.pending(), isEmpty);
  });
}
