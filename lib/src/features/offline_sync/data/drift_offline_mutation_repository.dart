import 'dart:convert';

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';
import 'package:drift/drift.dart';

class DriftOfflineMutationRepository implements OfflineMutationRepository {
  const DriftOfflineMutationRepository(this.database);

  final AppDatabase database;

  @override
  Future<void> enqueue(OfflineMutation mutation) =>
      database.enqueueCloudMutation(PendingCloudMutationsCompanion.insert(
        id: mutation.id,
        entityType: mutation.entityType,
        entityId: mutation.entityId,
        operation: mutation.operation.name,
        payloadJson: jsonEncode(mutation.payload),
        baseVersion: Value(mutation.baseVersion),
        createdAt: mutation.createdAt,
        attemptCount: Value(mutation.attemptCount),
        status: Value(mutation.status.name),
        conflictReason: Value(mutation.conflictReason),
      ));

  @override
  Future<List<OfflineMutation>> pending() async =>
      (await database.pendingCloudMutationRows()).map(_map).toList();

  @override
  Future<void> markApplied(String id) =>
      database.updateCloudMutationStatus(id, status: 'applied');

  @override
  Future<void> markConflict(String id, String reason) =>
      database.updateCloudMutationStatus(
        id,
        status: 'conflict',
        conflictReason: reason,
      );

  @override
  Future<void> markRetry(String id, String reason) =>
      database.updateCloudMutationStatus(
        id,
        status: 'pending',
        conflictReason: reason,
        incrementAttempt: true,
      );

  OfflineMutation _map(PendingCloudMutation row) => OfflineMutation(
        id: row.id,
        entityType: row.entityType,
        entityId: row.entityId,
        operation: OfflineMutationOperation.values.byName(row.operation),
        payload: (jsonDecode(row.payloadJson) as Map)
            .map((key, value) => MapEntry('$key', value)),
        baseVersion: row.baseVersion,
        createdAt: row.createdAt,
        attemptCount: row.attemptCount,
        status: OfflineMutationStatus.values.byName(row.status),
        conflictReason: row.conflictReason,
      );
}
