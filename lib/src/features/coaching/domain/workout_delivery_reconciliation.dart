enum WorkoutReconciliationStatus { current, missing, externallyDiverged }

class ProviderWorkoutSnapshot {
  const ProviderWorkoutSnapshot({
    required this.externalId,
    required this.contentHash,
    this.providerWorkoutId,
  });

  final String externalId;
  final String contentHash;
  final String? providerWorkoutId;
}

class WorkoutReconciliationResult {
  const WorkoutReconciliationResult({
    required this.externalId,
    required this.status,
    required this.expectedHash,
    this.observedHash,
    this.providerWorkoutId,
  });

  final String externalId;
  final WorkoutReconciliationStatus status;
  final String expectedHash;
  final String? observedHash;
  final String? providerWorkoutId;
}

List<WorkoutReconciliationResult> reconcileWorkoutCalendar({
  required Iterable<ProviderWorkoutSnapshot> expected,
  required Iterable<ProviderWorkoutSnapshot> observed,
}) {
  final remoteByExternalId = {
    for (final workout in observed) workout.externalId: workout,
  };
  return expected.map((local) {
    final remote = remoteByExternalId[local.externalId];
    final status = remote == null
        ? WorkoutReconciliationStatus.missing
        : remote.contentHash == local.contentHash
            ? WorkoutReconciliationStatus.current
            : WorkoutReconciliationStatus.externallyDiverged;
    return WorkoutReconciliationResult(
      externalId: local.externalId,
      status: status,
      expectedHash: local.contentHash,
      observedHash: remote?.contentHash,
      providerWorkoutId: remote?.providerWorkoutId,
    );
  }).toList(growable: false);
}
