import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCloudSnapshotRepository implements CloudSnapshotRepository {
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
}
