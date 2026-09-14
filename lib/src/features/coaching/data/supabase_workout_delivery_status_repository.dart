import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseWorkoutDeliveryStatusRepository
    implements WorkoutDeliveryStatusRepository {
  const SupabaseWorkoutDeliveryStatusRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<CalendarWorkoutDeliveryState>> fetchRange(
    DateTime start,
    DateTime end,
  ) async {
    if (client.auth.currentUser == null) return const [];
    String day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final rows = await client
        .from('workout_deliveries')
        .select('planned_session_id,provider,delivery_status,'
            'external_workout_id,desired_content_hash,acknowledged_content_hash,'
            'desired_version,acknowledged_version,attempt_count,failure_message,'
            'updated_at,planned_sessions!inner(scheduled_date)')
        .gte('planned_sessions.scheduled_date', day(start))
        .lte('planned_sessions.scheduled_date', day(end));
    return rows
        .map(CalendarWorkoutDeliveryState.fromJson)
        .toList(growable: false);
  }

  @override
  Future<bool> retry(String plannedSessionId,
      {required String provider}) async {
    if (client.auth.currentUser == null) return false;
    return await client.rpc('retry_workout_delivery', params: {
          'p_planned_session_id': plannedSessionId,
          'p_provider': provider,
        }) ==
        true;
  }

  @override
  Future<int> retryFuture({required String provider}) async {
    if (client.auth.currentUser == null) return 0;
    final value = await client.rpc('retry_future_workout_deliveries', params: {
      'p_provider': provider,
    });
    return (value as num?)?.toInt() ?? 0;
  }
}
