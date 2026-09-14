import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609090001_add_workout_delivery_retry.sql',
  ).readAsStringSync();

  test('retry is athlete-owned and limited to future planned workouts', () {
    expect(sql, contains('public.owns_athlete(wd.athlete_id)'));
    expect(sql, contains('ps.scheduled_date >= current_date'));
    expect(sql, contains("ps.completion_status = 'planned'"));
    expect(sql, contains("wd.delivery_status = 'failed'"));
  });

  test('retry reuses failed commands without creating duplicates', () {
    expect(sql, contains("status = 'failed'"));
    expect(sql, contains("set status = 'pending'"));
    expect(sql, contains('next_attempt_at = now()'));
    expect(sql, contains('retry_future_workout_deliveries'));
  });

  test('only authenticated users may invoke retry functions', () {
    expect(
        sql, contains('revoke all on function public.retry_workout_delivery'));
    expect(sql, contains('to authenticated'));
  });
}
