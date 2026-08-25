import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_sync_service.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _MemoryCloudRepository repository;
  final now = DateTime.utc(2026, 8, 25, 20, 30);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = _MemoryCloudRepository();
  });
  tearDown(() => database.close());

  test('first sync uploads a complete schema-versioned snapshot', () async {
    final service = CloudSyncService(
      database: database,
      repository: repository,
      deviceName: 'Neil Android',
      now: () => now,
    );

    expect(await service.uploadIfSafe(), CloudSyncOutcome.uploaded);
    expect(repository.saved, isNotNull);
    expect(repository.saved!.schemaVersion, database.schemaVersion);
    expect(repository.saved!.sourceDevice, 'Neil Android');
    expect(repository.saved!.payload['activities'], isA<List>());
    expect(repository.saved!.payload['athleteSettings'], isA<List>());
    expect(repository.saved!.payload['activitySamples'], isEmpty);
    expect(
      repository.saved!.payload['omittedCloudSections'],
      ['activitySamples'],
    );
  });

  test('newer cloud state is never silently overwritten', () async {
    repository.value = CloudSnapshot(
      schemaVersion: database.schemaVersion,
      updatedAt: now.add(const Duration(minutes: 1)),
      sourceDevice: 'Web',
      payload: const {},
    );
    final service = CloudSyncService(
      database: database,
      repository: repository,
      deviceName: 'Android',
      now: () => now,
    );

    expect(await service.uploadIfSafe(), CloudSyncOutcome.remoteIsNewer);
    expect(repository.saved, isNull);
  });

  test('known unchanged cloud state is replaced by current local state',
      () async {
    repository.value = CloudSnapshot(
      schemaVersion: database.schemaVersion,
      updatedAt: now.subtract(const Duration(minutes: 1)),
      sourceDevice: 'Web',
      payload: const {},
    );
    final service = CloudSyncService(
      database: database,
      repository: repository,
      deviceName: '',
      now: () => now,
    );

    expect(
      await service.uploadIfSafe(
        lastKnownRemoteUpdate: repository.value!.updatedAt,
      ),
      CloudSyncOutcome.uploaded,
    );
    expect(repository.saved!.sourceDevice, 'CycleReady device');
  });

  test('detailed samples upload in chunks before snapshot commit', () async {
    await database.into(database.activities).insert(ActivitiesCompanion.insert(
          id: 'ride-1',
          source: 'test',
          startedAt: now,
          durationSeconds: 3,
          distanceMetres: 30,
        ));
    await database.saveActivitySamples([
      ActivitySamplesCompanion.insert(
        activityId: 'ride-1',
        elapsedSeconds: 0,
        power: const Value(180),
      ),
      ActivitySamplesCompanion.insert(
        activityId: 'ride-1',
        elapsedSeconds: 1,
        power: const Value(220),
      ),
    ]);
    final samples = _MemorySampleRepository();
    final service = CloudSyncService(
      database: database,
      repository: repository,
      sampleRepository: samples,
      deviceName: 'Android',
      now: () => now,
    );

    expect(await service.uploadIfSafe(), CloudSyncOutcome.uploaded);
    expect(samples.chunks['ride-1'], hasLength(1));
    expect(samples.chunks['ride-1']!.single.samples, hasLength(2));
    expect(repository.saved, isNotNull);
  });
}

class _MemoryCloudRepository implements CloudSnapshotRepository {
  CloudSnapshot? value;
  CloudSnapshot? saved;

  @override
  Future<CloudSnapshot?> fetch() async => value;

  @override
  Future<void> save(CloudSnapshot snapshot) async {
    saved = snapshot;
    value = snapshot;
  }
}

class _MemorySampleRepository implements CloudActivitySampleRepository {
  final chunks = <String, List<CloudActivitySampleChunk>>{};

  @override
  Future<List<CloudActivitySample>> fetchForActivity(String activityId) async =>
      chunks[activityId]?.expand((chunk) => chunk.samples).toList() ?? const [];

  @override
  Future<void> replaceActivityChunks(
    String activityId,
    List<CloudActivitySampleChunk> values,
  ) async {
    chunks[activityId] = values;
  }
}
