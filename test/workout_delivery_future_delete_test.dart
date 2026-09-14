import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080016_queue_future_workout_deletion.sql',
  ).readAsStringSync();

  test('future delivered plan deletion queues a provider delete', () {
    expect(sql, contains('before delete on public.planned_sessions'));
    expect(sql, contains('old.scheduled_date < current_date'));
    expect(sql, contains("delivery.provider, 'delete'"));
    expect(
        sql, contains("'external_workout_id', delivery.external_workout_id"));
  });

  test('undelivered create is cancelled without a provider delete', () {
    expect(sql, contains('delivery.external_workout_id is null'));
    expect(sql, contains("set status = 'completed'"));
    expect(sql, contains("delivery_status = 'deleted'"));
  });

  test('delivery audit survives planned session removal', () {
    expect(sql, contains('alter column planned_session_id drop not null'));
    expect(sql, contains('on delete set null'));
  });
}
