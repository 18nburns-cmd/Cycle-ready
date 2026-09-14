import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('supabase/functions/daily-coaching/index.ts').readAsStringSync();

  test('daily orchestrator runs readiness before adaptive safety selection',
      () {
    final readiness = source.indexOf("runStage('process-readiness'");
    final adaptive = source.indexOf("runStage('process-adaptive-decision'");
    expect(readiness, greaterThan(0));
    expect(adaptive, greaterThan(readiness));
    expect(source, contains("rpc('assemble_daily_coaching_context'"));
  });

  test('daily orchestrator authenticates jobs and emits versioned output', () {
    expect(source, contains('CYCLEREADY_SYNC_JOB_SECRET'));
    expect(source, contains('DAILY_COACHING_CONTRACT_VERSION'));
    expect(source, contains('evidence_snapshot'));
    expect(source, contains('idempotency_key'));
  });

  test('unchanged material evidence reuses the existing recommendation', () {
    expect(source, contains('evidence_fingerprint'));
    expect(source,
        contains('previous.data?.evidence_fingerprint === fingerprint'));
    expect(source, contains('reused: true'));
    expect(
      source.indexOf('previous.data?.evidence_fingerprint === fingerprint'),
      lessThan(source.indexOf("runStage('process-adaptive-decision'")),
    );
  });
}
