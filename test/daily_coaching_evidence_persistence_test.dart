import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommendation audit record preserves exact input and evidence', () {
    final sql = File(
      'supabase/migrations/202609080006_add_daily_coaching_recommendations.sql',
    ).readAsStringSync().toLowerCase();
    expect(sql, contains('input_snapshot jsonb not null'));
    expect(sql, contains('evidence_snapshot jsonb not null'));
    expect(sql, contains('recommendation jsonb not null'));
    expect(sql, contains('model_version text not null'));
  });

  test('orchestrator persists the assembled context and output together', () {
    final source =
        File('supabase/functions/daily-coaching/index.ts').readAsStringSync();
    expect(source, contains("from('daily_coaching_recommendations').upsert"));
    expect(source, contains('input_snapshot: context.data'));
    expect(source, contains('evidence_snapshot: evidence'));
    expect(source, contains('recommendation: output'));
  });

  test('one athlete-day is persisted idempotently', () {
    final sql = File(
      'supabase/migrations/202609080007_add_daily_coaching_idempotency.sql',
    ).readAsStringSync().toLowerCase();
    final source =
        File('supabase/functions/daily-coaching/index.ts').readAsStringSync();
    expect(sql, contains('unique (athlete_id, coaching_date)'));
    expect(sql, contains('idempotency_key_unique'));
    expect(source, contains("onConflict: 'athlete_id,coaching_date'"));
  });
}
