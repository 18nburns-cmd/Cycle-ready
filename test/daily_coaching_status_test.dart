import 'dart:io';

import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses completed and failed cloud status fields', () {
    final status = DailyCoachingStatus.fromJson({
      'last_run_at': '2026-09-08T05:00:00Z',
      'next_run_at': '2026-09-09T05:00:00Z',
      'model_version': 'daily-v1',
      'status': 'FAILED',
      'failure_code': 'TimeoutException',
      'failure_message': 'stage timed out',
      'attempt_number': 2,
      'timezone': 'Europe/London',
    });
    expect(status.status, DailyCoachingRunStatus.failed);
    expect(status.failureCode, 'TimeoutException');
    expect(status.attemptNumber, 2);
    expect(status.nextRunAt.isUtc, isTrue);
  });

  test('status RPC exposes schedule, model and failure without private tables',
      () {
    final sql = File(
      'supabase/migrations/202609080011_add_daily_coaching_status_rpc.sql',
    ).readAsStringSync().toLowerCase();
    expect(sql, contains('get_daily_coaching_status'));
    expect(sql, contains('next_run_at'));
    expect(sql, contains('model_version'));
    expect(sql, contains('failure_message'));
    expect(sql, contains('public.owns_athlete(requested_athlete_id)'));
  });
}
