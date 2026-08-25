import 'package:cycle_ready/src/features/intervals/domain/intervals_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FTP session produces native repeat syntax', () {
    final text = intervalsWorkoutDescription(
      sessionType: 'intervals',
      durationMinutes: 70,
    );
    expect(text, contains('4x'));
    expect(text, contains('- 8m 102%'));
    expect(text, contains('- 4m 50%'));
  });

  test('endurance duration is retained', () {
    expect(
      intervalsWorkoutDescription(
        sessionType: 'endurance',
        durationMinutes: 150,
      ),
      '- 150m 66%',
    );
  });
}
