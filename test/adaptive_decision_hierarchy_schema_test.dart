import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database accepts every adaptation-first hierarchy level', () {
    final migration = File(
      'supabase/migrations/202609130002_expand_adaptation_level_hierarchy.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('adaptive_decisions_adaptation_level_check'),
    );
    expect(migration, contains('adaptation_level between 0 and 7'));
  });
}
