import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates changes from chronologically ordered snapshots', () {
    final earlier = _state(
      day: 1,
      fitness: 50,
      fatigue: 40,
      readiness: 60,
      weight: 72,
    );
    final later = _state(
      day: 8,
      fitness: 54,
      fatigue: 38,
      readiness: 74,
      weight: 71.5,
    );

    final trend = calculateAthleteStateTrend([later, earlier]);

    expect(trend, isNotNull);
    expect(trend!.from, earlier.updatedAt);
    expect(trend.to, later.updatedAt);
    expect(trend.fitnessChange, 4);
    expect(trend.fatigueChange, -2);
    expect(trend.readinessChange, 14);
    expect(trend.weightChangeKg, -0.5);
  });

  test('does not infer a trend from one snapshot', () {
    expect(
      calculateAthleteStateTrend([
        _state(
          day: 1,
          fitness: 50,
          fatigue: 40,
          readiness: 60,
          weight: 72,
        ),
      ]),
      isNull,
    );
  });
}

AthleteState _state({
  required int day,
  required double fitness,
  required double fatigue,
  required double readiness,
  required double weight,
}) =>
    AthleteState(
      profile: AthleteProfile(
        name: 'Neil',
        experienceLevel: 'advanced',
        ftp: 255,
        maximumHeartRate: 188,
        restingHeartRate: 48,
        weightKg: weight,
        weeklyLoadTarget: 420,
      ),
      updatedAt: DateTime.utc(2026, 8, day),
      fitness: fitness,
      fatigue: fatigue,
      freshness: 100 - fatigue,
      readiness: readiness,
      recovery: readiness + 2,
    );
