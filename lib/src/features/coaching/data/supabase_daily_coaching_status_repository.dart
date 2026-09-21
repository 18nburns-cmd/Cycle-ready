import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDailyCoachingStatusRepository
    implements DailyCoachingStatusRepository {
  const SupabaseDailyCoachingStatusRepository(this.client);
  final SupabaseClient client;

  static const endpoint = 'daily-coaching';
  static const requestTimeout = Duration(seconds: 30);

  @override
  Future<DailyCoachingStatus> fetchStatus() async {
    final user = client.auth.currentUser;
    if (user == null) {
      _log('Status request stopped: no authenticated Supabase user.');
      throw StateError('Sign in before reading daily coaching status.');
    }
    final athleteId = await _athleteId();
    final result = await client.rpc('get_daily_coaching_status',
        params: {'requested_athlete_id': athleteId});
    return DailyCoachingStatus.fromJson(
        Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<DailyCoachingRecommendation?> fetchToday() async {
    final user = client.auth.currentUser;
    if (user == null) {
      _log('Offline fallback activated: no authenticated Supabase session.');
      return null;
    }
    try {
      final athleteId = await _athleteId();
      final now = DateTime.now();
      final day = _day(now);
      _log('Read recommendation user=${user.id} athlete=$athleteId day=$day.');
      final row = await client
          .from('daily_coaching_recommendations')
          .select('coaching_date,recommendation,model_version,generated_at')
          .eq('athlete_id', athleteId)
          .eq('coaching_date', day)
          .maybeSingle();
      final planned = await client
          .from('planned_sessions')
          .select(
            'session_type,purpose,planned_duration_minutes,planned_load',
          )
          .eq('athlete_id', athleteId)
          .eq('scheduled_date', day)
          .eq('completion_status', 'planned')
          .maybeSingle();
      final storedRecommendation = row == null ? null : _parseStored(row);
      final recommendationIsCurrent = storedRecommendation != null &&
          dailyCoachingRecommendationMatchesPlan(
            recommendation: storedRecommendation,
            plannedSessionType: planned?['session_type'] as String?,
            plannedTitle: planned?['purpose'] as String?,
            plannedDurationMinutes:
                (planned?['planned_duration_minutes'] as num?)?.round(),
            plannedTargetLoad: (planned?['planned_load'] as num?)?.round(),
          );
      if (recommendationIsCurrent) {
        _log('Authoritative recommendation loaded from relational storage.');
        return storedRecommendation;
      }

      if (row != null) {
        _log('Stored recommendation differs from the current planned session; '
            'requesting authoritative recalculation.');
      }

      final base = client.rest.url.replaceFirst('/rest/v1', '');
      _log('No stored row. POST $base/functions/v1/$endpoint '
          'user=${user.id} athlete=$athleteId.');
      final response = await client.functions.invoke(endpoint, body: {
        'contract_version': '1.0',
        'athlete_id': athleteId,
        'coaching_date': day,
        'timezone': 'Europe/London',
        'requested_at': now.toUtc().toIso8601String(),
      }).timeout(requestTimeout);
      _log('POST $endpoint HTTP ${response.status}; '
          'body=${_safeBody(response.data)}');
      if (response.status < 200 || response.status >= 300) {
        throw StateError(
            'HTTP ${response.status}: ${_safeBody(response.data)}');
      }
      try {
        return DailyCoachingRecommendation.fromOutputJson(
            Map<String, dynamic>.from(response.data as Map));
      } catch (error, stackTrace) {
        _log('JSON parsing failed: $error; body=${_safeBody(response.data)}',
            error: error, stackTrace: stackTrace);
        rethrow;
      }
    } on TimeoutException catch (error, stackTrace) {
      _log('Offline fallback activated: $endpoint timed out after 30s.',
          error: error, stackTrace: stackTrace);
      rethrow;
    } on FunctionException catch (error, stackTrace) {
      _log(
          'Offline fallback activated: endpoint=$endpoint HTTP '
          '${error.status}; error=${error.reasonPhrase}; '
          'body=${_safeBody(error.details)}',
          error: error,
          stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      _log('Offline fallback activated: server request failed: $error',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> _athleteId() async {
    return AuthenticatedAthleteResolver(client).resolveId();
  }

  DailyCoachingRecommendation _parseStored(Map<String, dynamic> row) {
    try {
      return DailyCoachingRecommendation.fromJson(row);
    } catch (error, stackTrace) {
      _log('Stored JSON parsing failed: $error; body=${_safeBody(row)}',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _safeBody(Object? body) {
    final encoded = body is String ? body : jsonEncode(body);
    return encoded.length <= 2000 ? encoded : '${encoded.substring(0, 2000)}…';
  }

  static void _log(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(message,
          name: 'CycleReady.serverCoaching',
          error: error,
          stackTrace: stackTrace);
}
