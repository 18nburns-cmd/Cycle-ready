import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080010_add_daily_coaching_run_retries.sql',
  ).readAsStringSync().toLowerCase();
  final edge =
      File('supabase/functions/daily-coaching/index.ts').readAsStringSync();

  test('failed runs retain bounded retry state', () {
    expect(sql, contains('create table public.daily_coaching_runs'));
    expect(sql, contains("status = 'failed'"));
    expect(sql, contains('next_retry_at'));
    expect(sql, contains('attempt_number < 10'));
    expect(edge, contains("status: 'FAILED'"));
    expect(edge, contains('Math.min(60, 5 * 2 **'));
  });

  test('retry scheduler is independent from imports', () {
    expect(sql, contains('retry_failed_daily_coaching'));
    expect(sql, contains('cycle-ready-daily-coaching-retry'));
    expect(sql, isNot(contains('intervals-sync')));
  });
}
