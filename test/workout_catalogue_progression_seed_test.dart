import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080003_link_workout_progressions.sql',
  ).readAsStringSync();

  test('every canonical family receives progression and regression links', () {
    expect(RegExp(r"\('[a-z]+(?:'[,)])").allMatches(sql).length,
        greaterThanOrEqualTo(16));
    expect(sql, contains("('introductory', 'developing', 'progression')"));
    expect(sql, contains("('developing', 'advanced', 'progression')"));
    expect(sql, contains("('advanced', 'developing', 'regression')"));
    expect(sql, contains("('developing', 'introductory', 'regression')"));
  });

  test('progression seeding is idempotent', () {
    expect(
        sql,
        contains(
            'on conflict (from_variant_id, to_variant_id, direction) do nothing'));
  });
}
