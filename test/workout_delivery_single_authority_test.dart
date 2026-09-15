import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OAuth calendars use the server outbox instead of phone publication',
      () {
    final controller = File(
      'lib/src/features/coaching/application/planned_session_controller.dart',
    ).readAsStringSync();
    expect(controller, contains('cloudOAuth?.isConnected()'));
    expect(controller, contains('.uploadFuturePlan()'));
    expect(
      controller.indexOf('cloudOAuth?.isConnected()'),
      lessThan(controller.indexOf('ref.read(workoutDeliveryProvider)')),
    );
  });

  test('server removes only identifiable CycleReady duplicates by event id',
      () {
    final worker = File(
      'supabase/functions/deliver-workouts/index.ts',
    ).readAsStringSync();
    expect(worker, contains('cleanupLegacyCycleReadyEvents'));
    expect(worker, contains("name.startsWith('CycleReady - ')"));
    expect(worker, contains('event.oauth_client_id'));
    expect(worker, contains('map((event) => ({ id: event.id }))'));
    expect(worker, contains('duplicates_removed'));
  });

  test('contract v3 requeues every future provider prescription', () {
    final migration = File(
      'supabase/migrations/202609150001_reconcile_legacy_intervals_duplicates.sql',
    ).readAsStringSync();
    expect(migration, contains("'delivery_contract_version', 3"));
    expect(migration, contains('scheduled_date >= current_date'));
  });
}
