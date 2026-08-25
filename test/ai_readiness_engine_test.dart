import 'package:cycle_ready/src/features/coaching/domain/ai_readiness_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AiReadinessEngine();

  test('does not penalise unavailable health metrics', () {
    final withoutHealth = engine.calculate(
      load7Days: 300,
      usualLoad7Days: 300,
      form: 0,
      recoveryHours: 8,
      fatigue: 2,
    );
    expect(withoutHealth.contributingFactors, isNot(contains('HRV')));
    expect(withoutHealth.score, greaterThan(60));
  });

  test('poor personal recovery signals reduce readiness', () {
    final good = engine.calculate(
      hrv: 55,
      hrvBaseline: 52,
      restingHr: 50,
      restingHrBaseline: 50,
      sleepHours: 8,
      sleepTargetHours: 8,
      load7Days: 300,
      usualLoad7Days: 300,
      form: 5,
      recoveryHours: 4,
      fatigue: 1,
    );
    final poor = engine.calculate(
      hrv: 38,
      hrvBaseline: 52,
      restingHr: 60,
      restingHrBaseline: 50,
      sleepHours: 5,
      sleepTargetHours: 8,
      load7Days: 450,
      usualLoad7Days: 300,
      form: -25,
      recoveryHours: 48,
      fatigue: 5,
    );
    expect(poor.score, lessThan(good.score));
    expect(poor.warningFactors, isNotEmpty);
  });
}
