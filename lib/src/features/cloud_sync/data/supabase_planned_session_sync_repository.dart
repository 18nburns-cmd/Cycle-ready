import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';

class SupabasePlannedSessionSyncRepository {
  const SupabasePlannedSessionSyncRepository(this.client);
  final SupabaseClient client;

  Future<void> replaceFuture(List<PlannedSession> sessions) async {
    final athleteId = await AuthenticatedAthleteResolver(client).resolveId();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localDays = sessions.map((session) => _day(session.day)).toSet();
    final remote = await client
        .from('planned_sessions')
        .select('id,scheduled_date')
        .eq('athlete_id', athleteId)
        .gte('scheduled_date', _day(today));
    for (final row in remote) {
      if (!localDays.contains('${row['scheduled_date']}')) {
        await client.from('planned_sessions').delete().eq('id', row['id']);
      }
    }
    for (final session in sessions) {
      await client.from('planned_sessions').upsert({
        'athlete_id': athleteId,
        'scheduled_date': _day(session.day),
        'scheduled_start_time': _startTime(session.adaptationReason),
        'session_type': session.sessionType,
        'primary_adaptation': session.sessionType,
        'purpose': session.title,
        'planned_duration_minutes': session.durationMinutes,
        'planned_load': session.targetLoad,
        'completion_status': 'planned',
        'source_evidence': {
          'origin': session.origin,
          'adaptation_reason': session.adaptationReason,
          'prescription': session.prescription,
        },
        'algorithm_version': session.origin == 'adaptive'
            ? 'flutter-adaptive-v3'
            : 'flutter-${session.origin}-v1',
      }, onConflict: 'athlete_id,scheduled_date');
    }
  }

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _startTime(String reason) {
    final match =
        RegExp(r'Scheduled for ([01]\d|2[0-3]):([0-5]\d)').firstMatch(reason);
    return match == null
        ? '09:00:00'
        : '${match.group(1)}:${match.group(2)}:00';
  }
}
