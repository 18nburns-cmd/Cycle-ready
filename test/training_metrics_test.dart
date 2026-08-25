import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly targets distinguish maintaining from building fitness', () {
    final targets = calculateWeeklyLoadTargets(50);
    expect(targets.maintain, 350);
    expect(targets.build, greaterThan(targets.maintain));
  });

  test('one hour at FTP produces 100 training-load points', () {
    expect(
      calculateTrainingLoad(
        durationSeconds: 3600,
        normalisedPower: 250,
        ftp: 250,
      ),
      100,
    );
  });

  test('daily strain starts at zero and rises with completed load', () {
    expect(calculateDailyStrain(0), 0);
    expect(calculateDailyStrain(100), closeTo(13.27, 0.01));
    expect(calculateDailyStrain(200), greaterThan(calculateDailyStrain(100)));
    expect(calculateDailyStrain(1000), lessThanOrEqualTo(21));
  });

  test('rolling load crosses midnight and decays over 24 hours', () {
    final now = DateTime(2026, 7, 30, 7);
    final load = calculateRolling24HourLoad([
      (
        finishedAt: DateTime(2026, 7, 29, 22),
        load: 100.0,
      ),
    ], now);
    expect(load, greaterThan(40));
    expect(load, lessThan(50));
    expect(
      calculateRolling24HourLoad([
        (
          finishedAt: DateTime(2026, 7, 29, 6),
          load: 100.0,
        ),
      ], now),
      0,
    );
  });

  test('sleep-cycle load resets at the next recorded wake time', () {
    final now = DateTime(2026, 7, 30, 9);
    final result = calculateSleepCycleLoad([
      (
        finishedAt: DateTime(2026, 7, 29, 18),
        load: 100.0,
      ),
      (
        finishedAt: DateTime(2026, 7, 30, 8),
        load: 40.0,
      ),
    ], now, latestSleepEnd: DateTime(2026, 7, 30, 7));

    expect(result, greaterThan(35));
    expect(result, lessThan(40));
  });

  test('sleep-cycle boundary falls back to 4am without timing data', () {
    expect(
      resolveSleepCycleStart(DateTime(2026, 7, 30, 3), null),
      DateTime(2026, 7, 29, 4),
    );
    expect(
      resolveSleepCycleStart(DateTime(2026, 7, 30, 8), null),
      DateTime(2026, 7, 30, 4),
    );
  });

  test('recent activity affects fatigue more than fitness', () {
    final now = DateTime(2026, 7, 27);
    final result = calculateFitnessMetrics([
      (date: now, load: 100.0),
    ], now);
    expect(result.fatigue, greaterThan(result.fitness));
    expect(result.weeklyLoad, 100);
    expect(result.form, lessThan(0));
  });

  test('heart rate provides a fallback when power is unavailable', () {
    final result = estimateActivityLoad(
      durationSeconds: 3600,
      averageHeartRate: 150,
      ftp: 250,
      restingHeartRate: 50,
      maximumHeartRate: 190,
    );
    expect(result.value, greaterThan(0));
    expect(result.confidence, LoadConfidence.measuredHeartRate);
  });
}
