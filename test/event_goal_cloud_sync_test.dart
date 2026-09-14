import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server migration gives every device event a stable identity', () {
    final sql = File(
      'supabase/migrations/202609130001_add_client_event_identity.sql',
    ).readAsStringSync();
    expect(sql, contains('client_goal_id integer'));
    expect(sql, contains('goals_athlete_client_identity'));
    expect(sql, contains('(athlete_id, client_goal_id)'));
    expect(sql, isNot(contains('delete from')));
  });

  test('event and plan sync use idempotent identities and preserve origin', () {
    final eventSync = File(
      'lib/src/features/cloud_sync/data/supabase_event_goal_sync_repository.dart',
    ).readAsStringSync();
    final planSync = File(
      'lib/src/features/cloud_sync/data/supabase_planned_session_sync_repository.dart',
    ).readAsStringSync();
    expect(eventSync, contains("onConflict: 'athlete_id,client_goal_id'"));
    expect(eventSync, contains(".not('client_goal_id', 'is', null)"));
    expect(planSync, contains("'origin': session.origin"));
    expect(planSync, contains("onConflict: 'athlete_id,scheduled_date'"));
  });
}
