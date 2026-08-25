import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCloudSnapshotRepository
    implements CloudSnapshotRepository, CloudActivitySampleRepository {
  const SupabaseCloudSnapshotRepository(this.client);

  final SupabaseClient client;

  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) {
      throw const CloudSyncUnavailable(
        'Sign in before synchronising CycleReady data.',
      );
    }
    return id;
  }

  @override
  Future<CloudSnapshot?> fetch() async {
    final row = await client
        .from('athlete_snapshots')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is! Map) {
      throw const FormatException('Cloud snapshot payload is invalid.');
    }
    return CloudSnapshot(
      schemaVersion: row['schema_version'] as int,
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      sourceDevice: row['source_device'] as String,
      payload: Map<String, Object?>.from(payload),
    );
  }

  @override
  Future<void> save(CloudSnapshot snapshot) =>
      client.from('athlete_snapshots').upsert({
        'user_id': _userId,
        'schema_version': snapshot.schemaVersion,
        'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
        'source_device': snapshot.sourceDevice,
        'payload': snapshot.payload,
      }, onConflict: 'user_id');

  @override
  Future<List<CloudActivitySample>> fetchForActivity(String activityId) async {
    final rows = await client
        .from('activity_sample_chunks')
        .select('chunk_index, payload')
        .eq('user_id', _userId)
        .eq('activity_id', activityId)
        .order('chunk_index');
    final samples = <CloudActivitySample>[];
    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! List) continue;
      samples.addAll(payload.whereType<Map>().map(
            (sample) => CloudActivitySample.fromJson(
              sample.map((key, value) => MapEntry('$key', value)),
            ),
          ));
    }
    samples.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
    return samples;
  }

  @override
  Future<void> replaceActivityChunks(
    String activityId,
    List<CloudActivitySampleChunk> chunks,
  ) async {
    if (chunks.isEmpty) {
      await client
          .from('activity_sample_chunks')
          .delete()
          .eq('user_id', _userId)
          .eq('activity_id', activityId);
      return;
    }
    await client.from('activity_sample_chunks').upsert(
          chunks
              .map((chunk) => {
                    'user_id': _userId,
                    'activity_id': activityId,
                    'chunk_index': chunk.index,
                    'sample_count': chunk.samples.length,
                    'first_elapsed_seconds': chunk.firstElapsedSeconds,
                    'last_elapsed_seconds': chunk.lastElapsedSeconds,
                    'content_hash': chunk.contentHash,
                    'payload':
                        chunk.samples.map((sample) => sample.toJson()).toList(),
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
              .toList(),
          onConflict: 'user_id,activity_id,chunk_index',
        );
    await client
        .from('activity_sample_chunks')
        .delete()
        .eq('user_id', _userId)
        .eq('activity_id', activityId)
        .gte('chunk_index', chunks.length);
  }
}
