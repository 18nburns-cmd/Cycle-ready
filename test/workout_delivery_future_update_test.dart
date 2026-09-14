import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only future planned workout changes enter provider delivery', () {
    final sql = File(
      'supabase/migrations/202609080015_limit_workout_updates_to_future.sql',
    ).readAsStringSync();
    expect(sql, contains('after insert or update of scheduled_date'));
    expect(sql, contains('new.scheduled_date >= current_date'));
    expect(sql, contains('public.queue_planned_workout_delivery()'));
  });
}
