import 'dart:io';

import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outbox contract represents create, update and delete operations', () {
    expect(WorkoutDeliveryOperationType.values, hasLength(3));
    final operation = WorkoutDeliveryOperation(
      deliveryId: 'delivery-1',
      provider: 'intervals-icu',
      type: WorkoutDeliveryOperationType.update,
      idempotencyKey: 'delivery-1:update:2',
      contentHash: List.filled(64, 'a').join(),
      payload: const {'title': 'Endurance'},
      createdAt: DateTime.utc(2026, 9, 8),
    );
    expect(operation.type, WorkoutDeliveryOperationType.update);
    expect(operation.payload['title'], 'Endurance');
  });

  test('server outbox is idempotent, ordered and athlete-owned', () {
    final sql = File(
      'supabase/migrations/202609080013_add_workout_delivery_outbox.sql',
    ).readAsStringSync();
    expect(sql, contains("operation in ('create', 'update', 'delete')"));
    expect(sql, contains('unique (athlete_id, idempotency_key)'));
    expect(sql, contains('next_attempt_at'));
    expect(sql, contains('public.owns_athlete(athlete_id)'));
  });

  test('Supabase repository checks the key before inserting', () {
    final source = File(
      'lib/src/features/coaching/data/supabase_workout_delivery_outbox_repository.dart',
    ).readAsStringSync();
    expect(
        source, contains(".eq('idempotency_key', operation.idempotencyKey)"));
    expect(source, contains(".eq('status', 'pending')"));
    expect(source, contains(".order('created_at')"));
  });

  test('server worker claims atomically and provider writes are idempotent',
      () {
    final migration = File(
      'supabase/migrations/202609120001_schedule_workout_delivery.sql',
    ).readAsStringSync();
    final worker = File(
      'supabase/functions/deliver-workouts/index.ts',
    ).readAsStringSync();
    expect(migration, contains('for update of o skip locked'));
    expect(migration, contains('o.content_hash <> d.desired_content_hash'));
    expect(migration, contains("'*/2 * * * *'"));
    expect(worker, contains('events/bulk?upsert=true'));
    expect(worker, contains(r'`cycleready-${scheduledDate}`'));
    expect(worker, contains('legacyExternalId'));
    expect(worker, contains('external_id: externalId'));
    expect(worker, contains(".eq('desired_content_hash', job.content_hash)"));
    expect(worker, contains(".eq('status', 'processing')"));
  });

  test('canonical Intervals IDs migration requeues future workouts', () {
    final migration = File(
      'supabase/migrations/202609130004_canonical_intervals_workout_ids.sql',
    ).readAsStringSync();
    expect(migration, contains("'delivery_contract_version', 2"));
    expect(migration, contains('scheduled_date >= current_date'));
    expect(migration, contains('set planned_load = planned_load'));
  });

  test('phone plan synchronization preserves day and scheduled time', () {
    final migration = File(
      'supabase/migrations/202609120002_sync_planned_session_time.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/src/features/cloud_sync/data/supabase_planned_session_sync_repository.dart',
    ).readAsStringSync();
    expect(migration, contains('scheduled_start_time'));
    expect(migration, contains('planned_sessions_athlete_day_unique'));
    expect(repository, contains("onConflict: 'athlete_id,scheduled_date'"));
    expect(repository, contains("RegExp(r'Scheduled for"));
  });
}
