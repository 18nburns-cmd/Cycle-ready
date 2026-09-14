import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/relational_coaching_data.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRelationalCoachingRepository
    implements RelationalCoachingRepository {
  const SupabaseRelationalCoachingRepository(this.client);

  final SupabaseClient client;

  @override
  Future<RelationalCoachingData> fetch() async {
    if (client.auth.currentUser == null) {
      throw const CloudSyncUnavailable(
        'Sign in before reading CycleReady coaching data.',
      );
    }
    final athleteId = await AuthenticatedAthleteResolver(client).resolveId();
    final athlete = _row(
        await client.from('athletes').select().eq('id', athleteId).single());
    final activities = _rows(await client
        .from('activities')
        .select()
        .eq('athlete_id', athleteId)
        .order('started_at', ascending: false)
        .limit(1000));
    final wellness = _rows(await client
        .from('daily_wellness_resolved')
        .select()
        .eq('athlete_id', athleteId)
        .order('recorded_date', ascending: false)
        .limit(366));
    final weights = _rows(await client
        .from('weight_history')
        .select()
        .eq('athlete_id', athleteId)
        .order('measured_at', ascending: false)
        .limit(366));
    final planned = _rows(await client
        .from('planned_sessions')
        .select()
        .eq('athlete_id', athleteId)
        .order('scheduled_date')
        .limit(366));
    final ftp = _rows(await client
        .from('ftp_history')
        .select()
        .eq('athlete_id', athleteId)
        .order('effective_date', ascending: false));
    final nutrition = _rows(await client
        .from('nutrition_entries')
        .select()
        .eq('athlete_id', athleteId)
        .order('recorded_at', ascending: false)
        .limit(1000));
    final nutritionTargets = _rows(await client
        .from('daily_nutrition_targets')
        .select()
        .eq('athlete_id', athleteId)
        .order('target_date', ascending: false)
        .limit(366));
    final readiness = await client
        .from('daily_readiness')
        .select()
        .eq('athlete_id', athleteId)
        .order('readiness_date', ascending: false)
        .limit(1)
        .maybeSingle();
    final decision = await client
        .from('adaptive_decisions')
        .select()
        .eq('athlete_id', athleteId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final updatedAt = <DateTime>[
      _date(athlete['updated_at']),
      if (activities.isNotEmpty) _date(activities.first['updated_at']),
      if (wellness.isNotEmpty) _date(wellness.first['resolved_at']),
      if (decision != null) _date(decision['created_at']),
    ].reduce((a, b) => a.isAfter(b) ? a : b);
    return RelationalCoachingData(
      athlete: athlete,
      activities: activities,
      wellness: wellness,
      weights: weights,
      plannedSessions: planned,
      ftpHistory: ftp,
      nutritionEntries: nutrition,
      nutritionTargets: nutritionTargets,
      latestReadiness: readiness == null ? null : _row(readiness),
      latestDecision: decision == null
          ? null
          : AuthoritativeCoachingDecision.fromJson(_row(decision)),
      updatedAt: updatedAt,
    );
  }
}

Map<String, Object?> _row(Map<dynamic, dynamic> value) =>
    value.map((key, value) => MapEntry('$key', value));

List<Map<String, Object?>> _rows(List<dynamic> values) => values
    .whereType<Map>()
    .map((value) => value.map((key, value) => MapEntry('$key', value)))
    .toList(growable: false);

DateTime _date(Object? value) =>
    DateTime.tryParse('$value')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
