import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';

class SupabaseEventGoalSyncRepository {
  const SupabaseEventGoalSyncRepository(this.client);

  final SupabaseClient client;

  Future<void> replaceEvents(List<CoachingEventGoal> events) async {
    final athleteId = await AuthenticatedAthleteResolver(client).resolveId();
    final ids = events.map((event) => event.id).whereType<int>().toSet();
    final synchronized = await client
        .from('goals')
        .select('id,client_goal_id')
        .eq('athlete_id', athleteId)
        .not('client_goal_id', 'is', null);
    for (final row in synchronized) {
      final clientId = row['client_goal_id'] as int?;
      if (clientId != null && !ids.contains(clientId)) {
        await client.from('goals').delete().eq('id', row['id']);
      }
    }
    for (final event in events) {
      if (event.id == null) continue;
      await client.from('goals').upsert({
        'athlete_id': athleteId,
        'client_goal_id': event.id,
        'name': event.name,
        'event_date': _day(event.eventDate),
        'event_type': _eventType(event),
        'priority': event.priority,
        'distance_metres': event.distanceKm * 1000,
        'elevation_metres': event.elevationMetres,
        'expected_duration_seconds':
            (event.distanceKm / _estimatedSpeed(event.terrain) * 3600).round(),
        'target_performance': event.target,
        'notes': 'terrain=${event.terrain};available_days='
            '${event.availableDays};long_ride_minutes=${event.longRideMinutes}',
      }, onConflict: 'athlete_id,client_goal_id');
    }
  }

  static String _eventType(CoachingEventGoal event) =>
      event.target == 'race' ? 'road_race' : 'sportive';

  static double _estimatedSpeed(String terrain) => switch (terrain) {
        'mountainous' => 20,
        'flat' => 28,
        _ => 24,
      };

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
