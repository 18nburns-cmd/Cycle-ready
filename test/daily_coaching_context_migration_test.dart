import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080005_add_daily_coaching_context.sql',
  ).readAsStringSync().toLowerCase();

  test('assembles a stable authoritative athlete-day context', () {
    expect(sql, contains('assemble_daily_coaching_context'));
    expect(sql, contains('language plpgsql'));
    expect(sql, contains('stable'));
    expect(sql, contains("'contract_version', '1.0'"));
    for (final source in [
      'daily_readiness',
      'daily_wellness_resolved',
      'planned_sessions',
      'athlete_availability',
      'activities',
      'goals',
    ]) {
      expect(sql, contains(source), reason: 'missing authoritative $source');
    }
  });

  test('context function enforces athlete ownership', () {
    expect(sql, contains('public.owns_athlete(requested_athlete_id)'));
    expect(sql, contains("auth.role() <> 'service_role'"));
  });
}
