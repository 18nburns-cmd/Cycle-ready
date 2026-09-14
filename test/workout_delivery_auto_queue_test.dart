import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080014_queue_confirmed_workout_delivery.sql',
  ).readAsStringSync();

  test('planned and adapted workout writes automatically enter the outbox', () {
    expect(sql, contains('after insert or update of scheduled_date'));
    expect(sql, contains('public.queue_planned_workout_delivery()'));
    expect(sql, contains("new.completion_status <> 'planned'"));
    expect(sql, contains("new.session_type = 'rest'"));
  });

  test('unchanged content does not create another command', () {
    expect(sql, contains('delivery.desired_content_hash = payload_hash'));
    expect(sql, contains('return new;'));
    expect(
        sql, contains('on conflict (athlete_id, idempotency_key) do nothing'));
  });

  test('provider acknowledgement selects create or update', () {
    expect(sql, contains("delivery.external_workout_id is null then 'create'"));
    expect(sql, contains("else 'update'"));
    expect(sql, contains("delivery_status = 'pending'"));
  });
}
