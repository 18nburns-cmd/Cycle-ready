import 'package:cycle_ready/src/features/readiness/domain/readiness_calculator.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ReadinessCalculator();

  test('well-recovered athlete receives high readiness', () {
    final result = calculator.calculate(_input());
    expect(result.score, greaterThanOrEqualTo(67));
    expect(result.band, ReadinessBand.high);
  });

  test('poor recovery and excessive load produce low readiness', () {
    final result = calculator.calculate(_input(
      sleepMinutes: 240,
      restingHeartRate: 62,
      hrvMilliseconds: 30,
      recentTrainingLoad: 650,
      fatigue: 5,
      soreness: 5,
      stress: 5,
      motivation: 1,
    ));
    expect(result.score, lessThan(34));
    expect(result.band, ReadinessBand.low);
  });

  test('missing HRV falls back to resting heart rate', () {
    final result = calculator.calculate(_input(hrvMilliseconds: null));
    expect(result.score, inInclusiveRange(0, 100));
  });

  test('missing recovery data stays neutral instead of reporting ready', () {
    final result = calculator.calculate(RecoveryInput.defaults());
    expect(result.band, ReadinessBand.moderate);
  });
}

RecoveryInput _input({
  int sleepMinutes = 480,
  double restingHeartRate = 50,
  double? hrvMilliseconds = 60,
  double recentTrainingLoad = 300,
  int fatigue = 1,
  int soreness = 1,
  int stress = 1,
  int motivation = 5,
}) =>
    RecoveryInput(
      sleepMinutes: sleepMinutes,
      sleepTargetMinutes: 480,
      sleepQuality: 90,
      restingHeartRate: restingHeartRate,
      baselineRestingHeartRate: 50,
      hrvMilliseconds: hrvMilliseconds,
      baselineHrvMilliseconds: hrvMilliseconds == null ? null : 60,
      recentTrainingLoad: recentTrainingLoad,
      normalTrainingLoad: 300,
      fatigue: fatigue,
      soreness: soreness,
      stress: stress,
      motivation: motivation,
      hasHealthData: true,
      hasSleepData: true,
      hasRecoverySignals: true,
      hasCheckIn: true,
    );
