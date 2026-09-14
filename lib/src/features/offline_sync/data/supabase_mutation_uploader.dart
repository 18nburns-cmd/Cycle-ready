import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';

class SupabaseMutationUploader {
  const SupabaseMutationUploader(this.client);

  final SupabaseClient client;

  static const _tables = <String, String>{
    'athlete_feedback': 'athlete_feedback',
    'wellness_observation': 'wellness',
    'activity': 'activities',
    'goal': 'goals',
  };

  Future<ConflictResolution> upload(OfflineMutation mutation) async {
    final table = _tables[mutation.entityType];
    if (table == null) {
      throw ArgumentError.value(
        mutation.entityType,
        'entityType',
        'Unsupported cloud mutation entity',
      );
    }
    final remote = await client
        .from(table)
        .select(mutation.operation == OfflineMutationOperation.append
            ? 'id'
            : 'id, updated_at')
        .eq('id', mutation.entityId)
        .maybeSingle();
    final resolution = resolveMutationConflict(
      mutation: mutation,
      remoteVersion: remote?['updated_at'] as String?,
      remoteEntityExists: remote != null,
    );
    if (resolution != ConflictResolution.apply) return resolution;
    final athleteId = await AuthenticatedAthleteResolver(client).resolveId();
    final payload = {
      ...mutation.payload,
      'athlete_id': athleteId,
      'id': mutation.entityId,
    };
    switch (mutation.operation) {
      case OfflineMutationOperation.upsert:
      case OfflineMutationOperation.append:
        await client.from(table).upsert(payload);
      case OfflineMutationOperation.delete:
        await client.from(table).delete().eq('id', mutation.entityId);
    }
    return ConflictResolution.apply;
  }
}
