import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a server delivery row to its calendar day and state', () {
    final entry = CalendarWorkoutDeliveryState.fromJson({
      'planned_session_id': 'plan-1',
      'provider': 'intervals-icu',
      'delivery_status': 'externally_diverged',
      'desired_version': 2,
      'acknowledged_version': 1,
      'attempt_count': 1,
      'updated_at': '2026-09-08T06:00:00Z',
      'planned_sessions': {'scheduled_date': '2026-09-10'},
    });
    expect(entry.day, DateTime(2026, 9, 10));
    expect(entry.delivery.status, WorkoutDeliveryStatus.externallyDiverged);
    expect(entry.delivery.desiredVersion, 2);
  });
}
