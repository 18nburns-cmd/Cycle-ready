import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrations = [
    'supabase/migrations/202609080001_add_workout_catalogue.sql',
    'supabase/migrations/202609080002_seed_workout_catalogue.sql',
    'supabase/migrations/202609080003_link_workout_progressions.sql',
    'supabase/migrations/202609080004_add_workout_duration_variants.sql',
  ].map((path) => File(path).readAsStringSync().toLowerCase()).toList();

  test('catalogue migrations are safe to reapply', () {
    expect(migrations[0], contains('create table if not exists'));
    expect(migrations[1], contains('on conflict (id) do update'));
    expect(migrations[2], contains('on conflict'));
    expect(migrations[3], contains('add column if not exists'));
  });

  test('catalogue migrations never mutate athlete plan history', () {
    final combined = migrations.join('\n');
    for (final statement in [
      'delete from public.planned_sessions',
      'update public.planned_sessions',
      'truncate public.planned_sessions',
      'delete from public.completed_sessions',
      'update public.completed_sessions',
      'truncate public.completed_sessions',
    ]) {
      expect(combined, isNot(contains(statement)));
    }
  });

  test('catalogue foreign keys cascade only inside catalogue tables', () {
    expect(migrations.first,
        contains('references public.workout_catalogue_variants'));
    expect(migrations.first,
        isNot(contains('references public.planned_sessions')));
  });
}
