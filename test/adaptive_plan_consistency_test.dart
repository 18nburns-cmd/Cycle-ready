import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/202609210001_keep_adaptive_plan_fields_consistent.sql',
  ).readAsStringSync();
  final function = File(
    'supabase/functions/process-adaptive-decision/index.ts',
  ).readAsStringSync();

  test('adaptive decision updates every calendar workout display field', () {
    for (final field in [
      'session_type =',
      'purpose =',
      'planned_duration_minutes =',
      'planned_load =',
      'current_workout_id =',
      'adaptation_status =',
    ]) {
      expect(migration, contains(field), reason: field);
    }
    expect(migration, contains("then 'rest'"));
    expect(migration, contains('planned_duration_minutes >= 0'));
  });

  test('adaptive output includes the calendar title, family and target load',
      () {
    expect(function, contains('normalizedReplacement'));
    expect(function, contains('family:'));
    expect(function, contains('title:'));
    expect(function, contains('target_load:'));
    expect(function, contains('planSignature'));
  });
}
