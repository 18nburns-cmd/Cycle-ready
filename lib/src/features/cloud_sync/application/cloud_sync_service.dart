import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';

enum CloudSyncOutcome { uploaded, remoteIsNewer }

class CloudSyncService {
  const CloudSyncService({
    required this.database,
    required this.repository,
    required this.deviceName,
    this.sampleRepository,
    this.now = DateTime.now,
  });

  final AppDatabase database;
  final CloudSnapshotRepository repository;
  final CloudActivitySampleRepository? sampleRepository;
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
    await uploadDetailedActivitySamples();
    // Commit the small headline snapshot last. If a chunk request fails, the
    // previous snapshot timestamp remains unchanged and a retry cannot be
    // mistaken for a cross-device conflict.
    await repository.save(local);
    return CloudSyncOutcome.uploaded;
  }

  Future<void> uploadDetailedActivitySamples() async {
    final destination = sampleRepository;
    if (destination == null) return;
    final activities = await database.getActivities();
    for (final activity in activities) {
      final localSamples = await database.samplesFor(activity.id);
      final chunks = chunkActivitySamples(
        activityId: activity.id,
        samples: localSamples.map(
          (sample) => CloudActivitySample(
            elapsedSeconds: sample.elapsedSeconds,
            heartRate: sample.heartRate,
            power: sample.power,
            cadence: sample.cadence,
            altitudeMetres: sample.altitudeMetres,
            distanceMetres: sample.distanceMetres,
            latitude: sample.latitude,
            longitude: sample.longitude,
          ),
        ),
      );
      await destination.replaceActivityChunks(activity.id, chunks);
    }
  }
}
