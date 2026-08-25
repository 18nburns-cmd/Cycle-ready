import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/morning_plan_adaptation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low morning readiness changes intervals to recovery', () {
    final change = adaptMorningWorkout(
      existingType: SessionType.intervals,
      readiness: 42,
      form: -5,
      rampRate: 3,
    );
    expect(change?.type, SessionType.recovery);
    expect(change?.reason, contains('42'));
  });

  test('moderate readiness reduces hard work to endurance', () {
    final change = adaptMorningWorkout(
      existingType: SessionType.tempo,
      readiness: 58,
      form: 0,
      rampRate: 2,
    );
    expect(change?.type, SessionType.endurance);
  });

  test('morning adaptation never increases an easy session', () {
    final change = adaptMorningWorkout(
      existingType: SessionType.endurance,
      readiness: 90,
      form: 15,
      rampRate: 2,
    );
    expect(change, isNull);
  });

  test('existing rest is preserved even with poor readiness', () {
    final change = adaptMorningWorkout(
      existingType: SessionType.rest,
      readiness: 20,
      form: -30,
      rampRate: 12,
    );
    expect(change, isNull);
  });
}
