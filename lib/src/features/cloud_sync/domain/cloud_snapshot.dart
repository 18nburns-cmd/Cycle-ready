class CloudSnapshot {
  const CloudSnapshot({
    required this.schemaVersion,
    required this.updatedAt,
    required this.sourceDevice,
    required this.payload,
  });

  final int schemaVersion;
  final DateTime updatedAt;
  final String sourceDevice;
  final Map<String, Object?> payload;
}

abstract interface class CloudSnapshotRepository {
  Future<CloudSnapshot?> fetch();

  Future<void> save(CloudSnapshot snapshot);
}

class CloudSyncUnavailable implements Exception {
  const CloudSyncUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
