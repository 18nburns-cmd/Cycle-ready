import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/power_development_focus.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_calculator.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = DailyCoachingEngine();
  const calculator = ReadinessCalculator();
  final now = DateTime(2026, 7, 27);

  TrainingMetrics metrics({double form = 5, double rampRate = 2}) =>
      TrainingMetrics(
        fitness: 45,
        fatigue: 45 - form,
        form: form,
        weeklyLoad: 300,
        rampRate: rampRate,
        history: const [],
      );

  test('good recovery produces a training session and seven-day outlook', () {
    final recovery = RecoveryInput.defaults().copyWith(
      sleepMinutes: 500,
      restingHeartRate: 49,
      hrvMilliseconds: 62,
      recentTrainingLoad: 300,
      fatigue: 1,
      soreness: 1,
      stress: 1,
      motivation: 5,
      hasHealthData: true,
    );
    final result = engine.build(
      now: now,
      readiness: calculator.calculate(recovery),
      recovery: recovery,
      metrics: metrics(),
    );

    expect(result.today.type, isNot(SessionType.rest));
    expect(result.outlook, hasLength(7));
    expect(result.insights, isNotEmpty);
    expect(result.today.confidence, inInclusiveRange(.35, .95));
    expect(result.today.evidence, isNotEmpty);
    expect(
        result.outlook.every((session) => session.evidence.isNotEmpty), isTrue);
  });

  test('excessive fatigue overrides a high numerical score', () {
    final recovery = RecoveryInput.defaults().copyWith(
      sleepMinutes: 520,
      restingHeartRate: 49,
      hrvMilliseconds: 65,
      recentTrainingLoad: 300,
      fatigue: 5,
      soreness: 1,
      stress: 1,
      motivation: 5,
      hasHealthData: true,
    );
    final result = engine.build(
      now: now,
      readiness: calculator.calculate(recovery),
      recovery: recovery,
      metrics: metrics(),
    );

    expect(result.today.type, SessionType.rest);
    expect(result.today.targetLoad, 0);
    expect(result.today.evidence.join(' '), contains('Readiness'));
  });

  test('high readiness targets the personal power limiter', () {
    final recovery = RecoveryInput.defaults().copyWith(
      sleepMinutes: 540,
      restingHeartRate: 48,
      hrvMilliseconds: 70,
      recentTrainingLoad: 200,
      fatigue: 1,
      soreness: 1,
      stress: 1,
      motivation: 5,
      hasHealthData: true,
    );
    final result = engine.build(
      now: now,
      readiness: const ReadinessResult(
        score: 88,
        band: ReadinessBand.high,
        headline: 'Ready',
        recommendation: 'Quality training is supported.',
        factors: [],
      ),
      recovery: recovery,
      metrics: metrics(form: 10),
      developmentFocus: const PowerDevelopmentFocus(
        area: PowerDevelopmentArea.vo2Max,
        relativeScore: .8,
        comparisonCount: 5,
      ),
    );
    expect(result.today.title, contains('VO2 max'));
    expect(result.today.reason, contains('eight-week power profile'));
    expect(result.today.evidence.join(' '), contains('5 comparable'));
    expect(result.today.confidence, greaterThan(.5));
  });
}
