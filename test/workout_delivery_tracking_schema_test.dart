import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609080012_add_workout_delivery_tracking.sql',
  ).readAsStringSync();

  test('persists provider identity, hashes, versions and attempts', () {
    for (final field in [
      'external_workout_id',
      'desired_content_hash',
      'acknowledged_content_hash',
      'desired_version',
      'acknowledged_version',
      'attempt_count',
      'last_attempt_at',
    ]) {
      expect(sql, contains(field), reason: field);
    }
    expect(sql, contains('unique (planned_session_id, provider)'));
    expect(sql, contains(r"desired_content_hash ~ '^[0-9a-f]{64}$'"));
  });

  test('delivery tracking is athlete-owned and exposes every domain state', () {
    expect(sql, contains('enable row level security'));
    expect(sql, contains('public.owns_athlete(athlete_id)'));
    for (final state in [
      'pending',
      'delivered',
      'updated',
      'deleted',
      'failed',
      'externally_diverged',
    ]) {
      expect(sql, contains("'$state'"), reason: state);
    }
  });
}
