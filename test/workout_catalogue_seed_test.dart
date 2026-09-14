import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080002_seed_workout_catalogue.sql',
  ).readAsStringSync();

  test('seed defines all canonical families and three difficulty variants', () {
    const families = [
      'recovery',
      'endurance',
      'longendurance',
      'tempo',
      'sweetspot',
      'threshold',
      'overunder',
      'vo2max',
      'anaerobic',
      'sprint',
      'neuromuscular',
      'cadence',
      'climbingendurance',
      'strengthendurance',
      'racesimulation',
      'fatigueresistance',
    ];
    for (final family in families) {
      expect(sql, contains("('$family'"));
    }
    expect(sql, contains("('introductory', 1"));
    expect(sql, contains("('developing', 2"));
    expect(sql, contains("('advanced', 3"));
  });

  test('seed is deterministic and safely repeatable', () {
    expect(sql, contains("family || '-' || difficulty || '-v1' as id"));
    expect(sql, contains('on conflict (id) do update'));
    expect(sql, contains('on conflict (variant_id, step_index) do update'));
  });

  test('seed creates explicit workout phases in step order', () {
    expect(sql, contains("(0, 'warmUp'"));
    expect(sql, contains("(1, 'work'"));
    expect(sql, contains("(2, 'recovery'"));
    expect(sql, contains("(3, 'coolDown'"));
  });
}
