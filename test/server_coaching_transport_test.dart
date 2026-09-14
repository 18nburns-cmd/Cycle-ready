import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/src/features/coaching/data/supabase_daily_coaching_status_repository.dart',
  ).readAsStringSync();

  test('missing stored recommendation invokes the authoritative endpoint', () {
    expect(source, contains("static const endpoint = 'daily-coaching'"));
    expect(source, contains('.functions'));
    expect(source, contains('.invoke(endpoint'));
    expect(source, contains("'contract_version': '1.0'"));
    expect(source, contains('.timeout(requestTimeout)'));
  });

  test('transport logs every required diagnostic boundary', () {
    for (final evidence in [
      'HTTP',
      'timed out',
      'no authenticated Supabase session',
      'user=',
      'athlete=',
      'body=',
      'JSON parsing failed',
      'Offline fallback activated',
    ]) {
      expect(source, contains(evidence), reason: evidence);
    }
  });
}
