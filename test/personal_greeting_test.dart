import 'package:cycle_ready/src/features/dashboard/domain/personal_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the correct greeting for each part of the day', () {
    expect(personalGreeting(DateTime(2026, 7, 30, 8)), 'Good morning, Neil');
    expect(personalGreeting(DateTime(2026, 7, 30, 14)), 'Good afternoon, Neil');
    expect(personalGreeting(DateTime(2026, 7, 30, 20)), 'Good evening, Neil');
  });
}
