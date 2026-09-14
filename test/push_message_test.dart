import 'package:cycle_ready/src/features/notifications/domain/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps notification data and retains an approved destination', () {
    final message = PushMessage.fromData(const {
      'notification_id': 'n-1',
      'title': 'Workout ready',
      'body': 'Your endurance ride is ready.',
      'route': '/training-plan',
    });
    expect(message.id, 'n-1');
    expect(message.route, '/training-plan');
  });

  test('rejects an untrusted notification route', () {
    expect(safeNotificationRoute('https://example.com'), '/');
    expect(safeNotificationRoute('/activities/ride-123/debrief'),
        '/activities/ride-123/debrief');
  });
}
