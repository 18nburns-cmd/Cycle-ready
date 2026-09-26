import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const recoveryPolicyStart = '202609210001';
  final migrationDirectory = Directory('supabase/migrations');
  final recoveryDirectory = Directory('supabase/migrations/recovery');

  test('every new server migration has a complete recovery note', () {
    final migrations = migrationDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .where(
            (file) => _baseName(file.path).compareTo(recoveryPolicyStart) >= 0)
        .toList();

    expect(migrations, isNotEmpty);
    for (final migration in migrations) {
      final name = _baseName(migration.path).replaceAll('.sql', '');
      final note = File('${recoveryDirectory.path}/$name.md');
      expect(note.existsSync(), isTrue, reason: '$name needs a recovery note');
      final contents = note.readAsStringSync();
      for (final heading in const [
        '## Risk',
        '## Rollback',
        '## Forward recovery',
        '## Verification',
      ]) {
        expect(contents, contains(heading), reason: '$name: $heading');
      }
      expect(contents.toLowerCase(), isNot(contains('supabase db reset')),
          reason: '$name must not prescribe destructive production reset');
    }
  });

  test('latest adaptive-plan migration is safely forward-replaceable', () {
    final sql = File(
      'supabase/migrations/202609210001_keep_adaptive_plan_fields_consistent.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('drop constraint if exists'));
    expect(sql, contains('create or replace function'));
    expect(sql, contains('where id = target_session_id for update'));
    expect(sql, contains('decision_key'));
    expect(sql, contains('if decision_id is not null then return decision_id'));
    expect(sql, contains('planned_duration_minutes >= 0'));
  });
}

String _baseName(String path) => path.replaceAll('\\', '/').split('/').last;
