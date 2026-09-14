import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new authenticated users receive exactly one athlete profile', () {
    final migration = File(
      'supabase/migrations/202609130003_bootstrap_authenticated_athletes.sql',
    ).readAsStringSync();
    expect(migration, contains('after insert on auth.users'));
    expect(migration, contains('on conflict (user_id) do nothing'));
    expect(migration, contains('where not exists'));
  });

  test('Android accepts the password recovery deep link', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:scheme="com.cycleready.app"'));
    expect(manifest, contains('android:host="reset-password"'));
  });

  test('Intervals sync never assigns an unknown provider to a global athlete',
      () {
    final source =
        File('supabase/functions/intervals-sync/index.ts').readAsStringSync();
    expect(source, isNot(contains("from('athletes').select('id').limit(2)")));
    expect(
      source,
      contains('account-specific authorization'),
    );
  });

  test('provider credentials and delivery queues are athlete isolated', () {
    final credentials = File(
      'supabase/migrations/202609020008_add_intervals_oauth_credentials.sql',
    ).readAsStringSync();
    final outbox = File(
      'supabase/migrations/202609080013_add_workout_delivery_outbox.sql',
    ).readAsStringSync();
    expect(credentials, contains('unique (athlete_id, provider)'));
    expect(credentials, contains('revoke all on public.provider_credentials'));
    expect(outbox, contains('unique (athlete_id, idempotency_key)'));
    expect(outbox, contains('public.owns_athlete(athlete_id)'));
  });

  test('background coaching and notifications are resolved per athlete', () {
    final coaching = File(
      'supabase/migrations/202609080008_schedule_daily_coaching.sql',
    ).readAsStringSync();
    final notifications =
        File('supabase/functions/deliver-notifications/index.ts')
            .readAsStringSync();
    expect(coaching,
        contains('select id, coaching_timezone from public.athletes'));
    expect(coaching, contains("'athlete_id', athlete.id"));
    expect(
        notifications, contains(".eq('athlete_id', notification.athlete_id)"));
  });

  test('account deletion authenticates the caller and deletes only that user',
      () {
    final source =
        File('supabase/functions/delete-account/index.ts').readAsStringSync();
    expect(source, contains('auth.getUser(bearer)'));
    expect(source, contains('auth.admin.deleteUser(user.id)'));
    expect(source, isNot(contains('listUsers')));
  });
}
