import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080001_add_workout_catalogue.sql',
  ).readAsStringSync();

  test('catalogue schema stores variants, structured steps and progressions',
      () {
    expect(
        sql,
        contains(
            'create table if not exists public.workout_catalogue_variants'));
    expect(sql,
        contains('create table if not exists public.workout_catalogue_steps'));
    expect(
        sql,
        contains(
            'create table if not exists public.workout_catalogue_progressions'));
    expect(sql, contains('catalogue_version integer not null'));
  });

  test('catalogue is readable only by authenticated clients', () {
    expect(sql, contains('enable row level security'));
    expect(sql, contains('for select to authenticated using (true)'));
    expect(sql,
        contains('revoke all on public.workout_catalogue_variants from anon'));
    expect(sql, isNot(contains('for insert to authenticated')));
  });

  test('database constraints reject malformed workout structures', () {
    expect(sql, contains('duration_seconds > 0'));
    expect(sql, contains('power_low_percent <= power_high_percent'));
    expect(sql, contains('from_variant_id <> to_variant_id'));
  });
}
