import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';

enum CloudSyncOutcome { uploaded, remoteIsNewer }

class CloudSyncService {
  const CloudSyncService({
    required this.database,
    required this.repository,
    required this.deviceName,
    this.now = DateTime.now,
  });

  final AppDatabase database;
  final CloudSnapshotRepository repository;
  final String deviceName;
  final DateTime Function() now;

  Future<CloudSnapshot> createLocalSnapshot() async {
    final payload = await database.exportSnapshot();
    // Second-by-second samples can make a single JSON request tens of
    // megabytes. Ride headline metrics remain in activities; sample streams
    // will use chunked object storage in a later transport revision.
    payload['activitySamples'] = const <Object>[];
    payload['omittedCloudSections'] = const <String>['activitySamples'];
    return CloudSnapshot(
      schemaVersion: database.schemaVersion,
      updatedAt: now().toUtc(),
      sourceDevice:
          deviceName.trim().isEmpty ? 'CycleReady device' : deviceName,
      payload: payload,
    );
  }

  Future<CloudSyncOutcome> uploadIfSafe(
      {DateTime? lastKnownRemoteUpdate}) async {
    final local = await createLocalSnapshot();
    final remote = await repository.fetch();
    if (remote != null &&
        remote.updatedAt.toUtc() != lastKnownRemoteUpdate?.toUtc()) {
      return CloudSyncOutcome.remoteIsNewer;
    }
    await repository.save(local);
    return CloudSyncOutcome.uploaded;
  }
}
