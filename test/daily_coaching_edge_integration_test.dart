import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String edge;
  late String scheduler;
  late String retries;
  late String contract;

  setUpAll(() {
    edge =
        File('supabase/functions/daily-coaching/index.ts').readAsStringSync();
    scheduler = File(
      'supabase/migrations/202609080008_schedule_daily_coaching.sql',
    ).readAsStringSync();
    retries = File(
      'supabase/migrations/202609080010_add_daily_coaching_run_retries.sql',
    ).readAsStringSync();
    contract = File(
      'supabase/functions/_shared/daily-coaching-contract.ts',
    ).readAsStringSync();
  });

  test('scheduler envelope reaches the idempotent Edge Function path', () {
    expect(scheduler, contains('functions/v1/daily-coaching'));
    for (final field in [
      'contract_version',
      'athlete_id',
      'coaching_date',
      'timezone',
      'requested_at',
    ]) {
      expect(scheduler, contains("'$field'"), reason: field);
      expect(contract, contains("'$field'"), reason: field);
    }
    expect(
        edge, contains('previous.data?.evidence_fingerprint === fingerprint'));
    expect(edge, contains('reused: true'));
    expect(edge, contains("onConflict: 'athlete_id,coaching_date'"));
  });

  test('timezone-local day and morning window feed the request envelope', () {
    expect(
        scheduler,
        contains(
            'local_time := run_at at time zone athlete.coaching_timezone'));
    expect(scheduler, contains('extract(hour from local_time) = 5'));
    expect(scheduler, contains('extract(minute from local_time) < 15'));
    expect(scheduler, contains("'coaching_date', local_time::date"));
    expect(scheduler, contains("'timezone', athlete.coaching_timezone"));
  });

  test('failed run is retried through the same bounded Edge path', () {
    expect(edge, contains('previousAttempt >= 10'));
    expect(edge, contains('Math.min(60, 5 * 2 ** (runTracker.attempt - 1))'));
    expect(edge, contains("status: 'FAILED'"));
    expect(edge, contains('next_retry_at: nextRetry'));
    expect(retries,
        contains("where status = 'FAILED' and next_retry_at <= run_at"));
    expect(retries, contains('attempt_number < 10'));
    expect(retries, contains("set status = 'RETRYING'"));
    expect(retries, contains('functions/v1/daily-coaching'));
  });

  test('signed-in Flutter users are authenticated and athlete-scoped', () {
    expect(edge, contains("request.headers.get('authorization')"));
    expect(edge, contains('.auth.getUser(bearer)'));
    expect(edge, contains(".eq('user_id', authenticatedUserId)"));
    expect(edge, contains("{ error: 'Unauthorized' }"));
  });
}
