import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/202609120003_expand_strategic_planning_contract.sql',
    ).readAsStringSync();
  });

  test('adds Foundation without rewriting historical phase rows', () {
    expect(migration, contains("add value if not exists 'FOUNDATION'"));
    expect(migration, isNot(contains('update public.training_phases')));
    expect(migration, isNot(contains('delete from')));
  });

  test('persists capability evidence independently by dimension', () {
    for (final field in <String>[
      'dimension_confidence',
      'dimension_trends',
      'dimension_evidence_counts',
      'dimension_last_updated',
    ]) {
      expect(migration, contains('add column if not exists $field'));
    }
  });

  test('persists bounded block lifecycle and completion criteria', () {
    expect(migration, contains('minimum_duration_days'));
    expect(migration, contains('maximum_duration_days'));
    expect(migration, contains('completion_criteria'));
    for (final state in <String>[
      'CONTINUE',
      'PROGRESS',
      'EXTEND',
      'END',
      'DELOAD',
      'REBUILD',
    ]) {
      expect(migration, contains("'$state'"));
    }
  });

  test('stores weekly adaptation objectives before workout assignment', () {
    expect(migration, contains('secondary_adaptation'));
    expect(migration, contains('maintenance_adaptations'));
    expect(migration, contains('adaptation_objectives'));
  });
}
