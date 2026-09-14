import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider delete is limited to acknowledged CycleReady plans', () {
    final sql = File(
      'supabase/migrations/202609080017_guard_workout_provider_deletion.sql',
    ).readAsStringSync();
    expect(sql, contains("managed_by = 'cycleready'"));
    expect(sql, contains('delivery.external_workout_id is null'));
    expect(sql, contains("completion <> 'planned'"));
    expect(sql, contains('Completed workouts cannot be deleted'));
    expect(sql, contains('before insert or update of operation'));
  });
}
