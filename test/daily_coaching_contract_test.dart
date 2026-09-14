import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final contract = File(
    'supabase/functions/_shared/daily-coaching-contract.ts',
  ).readAsStringSync();

  test('daily coaching server contract is explicitly versioned', () {
    expect(contract, contains("DAILY_COACHING_CONTRACT_VERSION = '1.0'"));
    expect(contract, contains('type DailyCoachingInputV1'));
    expect(contract, contains('type DailyCoachingOutputV1'));
    expect(contract, contains('Unsupported daily coaching contract'));
  });

  test('contract carries evidence, safety explanation and traceability', () {
    for (final field in [
      'evidence_snapshot',
      'reason_codes',
      'explanation',
      'confidence',
      'idempotency_key',
      'model_version',
      'generated_at',
    ]) {
      expect(contract, contains(field), reason: 'missing $field');
    }
  });
}
