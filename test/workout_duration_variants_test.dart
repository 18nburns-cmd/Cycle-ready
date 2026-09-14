import 'dart:io';

import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain distinguishes short, standard and extended doses', () {
    expect(WorkoutDurationClass.values.map((value) => value.name),
        ['short', 'standard', 'extended']);
  });

  test('migration derives time variants without changing adaptation', () {
    final sql = File(
      'supabase/migrations/202609080004_add_workout_duration_variants.sql',
    ).readAsStringSync();

    expect(sql, contains("('short', 0.70::numeric)"));
    expect(sql, contains("('extended', 1.30::numeric)"));
    expect(sql, contains('source.adaptation_target'));
    expect(sql, contains("when step.role = 'work'"));
    expect(sql, contains('on conflict (variant_id, step_index) do update'));
  });
}
