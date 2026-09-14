import 'package:cycle_ready/src/features/readiness/domain/recovery_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 2, 12);

  RecoveryTimeEstimate estimate({
    List<({DateTime finishedAt, double load})>? sessions,
    int readiness = 75,
    int sleep = 85,
    double form = 0,
    double fatigue = 40,
    int perceivedFatigue = 2,
    int soreness = 2,
  }) =>
      calculateRecoveryTime(
        sessions: sessions ?? const [],
        now: now,
        readiness: readiness,
        sleepScore: sleep,
        form: form,
        acuteFatigue: fatigue,
        perceivedFatigue: perceivedFatigue,
        soreness: soreness,
      );

  test('shows ready when no recent training requires recovery', () {
    expect(estimate().remainingHours, 0);
    expect(estimate().displayValue, 'Ready');
  });

  test('always displays active recovery as total hours', () {
    const value = RecoveryTimeEstimate(
      remainingHours: 30,
      explanation: 'Test estimate.',
    );
    expect(value.displayValue, '30h');
  });

  test('harder sessions produce longer recovery estimates', () {
    final easy = estimate(sessions: [
      (finishedAt: now, load: 25),
    ]);
    final hard = estimate(sessions: [
      (finishedAt: now, load: 120),
    ]);
    expect(hard.remainingHours, greaterThan(easy.remainingHours));
  });

  test('demanding activity receives watch-style recovery allowance', () {
    final hard = estimate(sessions: [
      (finishedAt: now, load: 100),
    ]);
    expect(hard.remainingHours, greaterThanOrEqualTo(50));
    expect(hard.remainingHours, lessThanOrEqualTo(96));
  });

  test('recovery time falls as hours pass', () {
    final recent = estimate(sessions: [
      (finishedAt: now, load: 100),
    ]);
    final older = estimate(sessions: [
      (finishedAt: now.subtract(const Duration(hours: 12)), load: 100),
    ]);
    expect(older.remainingHours, lessThan(recent.remainingHours));
  });

  test('poor sleep and readiness extend the same training demand', () {
    final session = [(finishedAt: now, load: 80.0)];
    final recovered = estimate(sessions: session);
    final depleted = estimate(
      sessions: session,
      readiness: 35,
      sleep: 50,
      form: -25,
      fatigue: 85,
      perceivedFatigue: 5,
      soreness: 4,
    );
    expect(depleted.remainingHours, greaterThan(recovered.remainingHours));
  });

  test('difficult post-ride feedback extends recovery time', () {
    final session = [(finishedAt: now, load: 80.0)];
    final normal = estimate(sessions: session);
    final difficult = calculateRecoveryTime(
      sessions: session,
      now: now,
      readiness: 75,
      sleepScore: 85,
      form: 0,
      acuteFatigue: 40,
      perceivedFatigue: 2,
      soreness: 2,
      postRideEffort: 9,
      postRideLegFatigue: 8,
      postRideDiscomfort: 2,
    );

    expect(difficult.remainingHours, greaterThan(normal.remainingHours));
    expect(difficult.explanation, contains('post-ride feedback'));
  });

  test('post-ride discomfort receives the strongest extension', () {
    final session = [(finishedAt: now, load: 80.0)];
    final difficult = calculateRecoveryTime(
      sessions: session,
      now: now,
      readiness: 75,
      sleepScore: 85,
      form: 0,
      acuteFatigue: 40,
      perceivedFatigue: 2,
      soreness: 2,
      postRideEffort: 5,
      postRideLegFatigue: 5,
      postRideDiscomfort: 8,
    );

    expect(difficult.explanation, contains('post-ride discomfort'));
  });
}
