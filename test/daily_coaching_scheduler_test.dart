import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080008_schedule_daily_coaching.sql',
  ).readAsStringSync().toLowerCase();
  final edge =
      File('supabase/functions/daily-coaching/index.ts').readAsStringSync();

  test('scheduler evaluates five o clock in each athlete timezone', () {
    expect(sql, contains('run_at at time zone athlete.coaching_timezone'));
    expect(sql, contains('extract(hour from local_time) = 5'));
    expect(sql, contains('extract(minute from local_time) < 15'));
    expect(sql, contains("'*/15 * * * *'"));
    expect(sql, contains('pg_timezone_names'));
  });

  test('completed athlete-day is not queued twice', () {
    expect(sql, contains('daily_coaching_recommendations'));
    expect(sql, contains("recommendation.status = 'completed'"));
    expect(sql, contains('recommendation.coaching_date = local_time::date'));
  });

  test('scheduler uses the private rotating database secret', () {
    expect(sql, contains('vault.decrypted_secrets'));
    expect(sql, contains("'x-cycle-ready-scheduler-secret'"));
    expect(edge,
        contains("request.headers.get('x-cycle-ready-scheduler-secret')"));
    expect(edge, contains('await sha256(schedulerSecret)'));
  });

  test('same-day material evidence changes queue a refresh', () {
    for (final source in [
      'daily_readiness',
      'daily_wellness_resolved',
      'activities',
      'planned_sessions',
    ]) {
      expect(sql, contains(source), reason: 'missing $source freshness');
    }
    expect(sql, contains('> recommendation.generated_at'));
  });
}
