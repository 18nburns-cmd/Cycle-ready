enum OfflineMutationOperation { upsert, delete, append }

enum OfflineMutationStatus { pending, applied, conflict }

class OfflineMutation {
  const OfflineMutation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.baseVersion,
    this.attemptCount = 0,
    this.status = OfflineMutationStatus.pending,
    this.conflictReason,
  });

  final String id;
  final String entityType;
  final String entityId;
  final OfflineMutationOperation operation;
  final Map<String, Object?> payload;
  final String? baseVersion;
  final DateTime createdAt;
  final int attemptCount;
  final OfflineMutationStatus status;
  final String? conflictReason;
}

enum ConflictResolution { apply, alreadyApplied, conflict }

ConflictResolution resolveMutationConflict({
  required OfflineMutation mutation,
  required String? remoteVersion,
  required bool remoteEntityExists,
}) {
  if (mutation.operation == OfflineMutationOperation.append) {
    return remoteEntityExists
        ? ConflictResolution.alreadyApplied
        : ConflictResolution.apply;
  }
  if (mutation.baseVersion == null) {
    return remoteEntityExists
        ? ConflictResolution.conflict
        : ConflictResolution.apply;
  }
  return mutation.baseVersion == remoteVersion
      ? ConflictResolution.apply
      : ConflictResolution.conflict;
}

abstract interface class OfflineMutationRepository {
  Future<void> enqueue(OfflineMutation mutation);
  Future<List<OfflineMutation>> pending();
  Future<void> markApplied(String id);
  Future<void> markConflict(String id, String reason);
  Future<void> markRetry(String id, String reason);
}
