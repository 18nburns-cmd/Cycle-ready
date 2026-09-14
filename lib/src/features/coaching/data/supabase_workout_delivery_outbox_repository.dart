import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_outbox.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';

class SupabaseWorkoutDeliveryOutboxRepository
    implements WorkoutDeliveryOutboxRepository {
  const SupabaseWorkoutDeliveryOutboxRepository(this.client);

  final SupabaseClient client;

  @override
  Future<bool> enqueue(WorkoutDeliveryOperation operation) async {
    final athlete = await _athleteId();
    final existing = await client
        .from('workout_delivery_outbox')
        .select('id')
        .eq('athlete_id', athlete)
        .eq('idempotency_key', operation.idempotencyKey)
        .maybeSingle();
    if (existing != null) return false;
    await client.from('workout_delivery_outbox').insert({
      'athlete_id': athlete,
      'delivery_id': operation.deliveryId,
      'provider': operation.provider,
      'operation': operation.type.name,
      'idempotency_key': operation.idempotencyKey,
      'content_hash': operation.contentHash,
      'payload': operation.payload,
      'created_at': operation.createdAt.toUtc().toIso8601String(),
    });
    return true;
  }

  @override
  Future<List<WorkoutDeliveryOperation>> pending({String? provider}) async {
    final athlete = await _athleteId();
    var query = client
        .from('workout_delivery_outbox')
        .select()
        .eq('athlete_id', athlete)
        .eq('status', 'pending');
    if (provider != null) query = query.eq('provider', provider);
    final rows = await query.order('created_at');
    return rows.map(_operationFromRow).toList(growable: false);
  }

  Future<String> _athleteId() async {
    return AuthenticatedAthleteResolver(client).resolveId();
  }

  WorkoutDeliveryOperation _operationFromRow(Map<String, dynamic> row) =>
      WorkoutDeliveryOperation(
        deliveryId: '${row['delivery_id']}',
        provider: '${row['provider']}',
        type: WorkoutDeliveryOperationType.values.byName('${row['operation']}'),
        idempotencyKey: '${row['idempotency_key']}',
        contentHash: '${row['content_hash']}',
        payload: Map<String, Object?>.from(row['payload'] as Map),
        createdAt: DateTime.parse('${row['created_at']}').toUtc(),
      );
}
