import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('athlete state stores profile metrics and trends', () {
    final updatedAt = DateTime.utc(2026, 8, 25, 7);
    const profile = AthleteProfile(
      name: 'Neil',
      experienceLevel: 'advanced',
      ftp: 255,
      maximumHeartRate: 188,
      restingHeartRate: 48,
      weightKg: 71.5,
      weeklyLoadTarget: 420,
    );
    final state = AthleteState(
      profile: profile,
      updatedAt: updatedAt,
      fitness: 72,
      fatigue: 31,
      freshness: 69,
      readiness: 84,
      recovery: 88,
      hrvTrend: 4.5,
      weightTrend: -0.3,
    );

    expect(state.profile, profile);
    expect(state.updatedAt, updatedAt);
    expect(state.fitness, 72);
    expect(state.fatigue, 31);
    expect(state.freshness, 69);
    expect(state.readiness, 84);
    expect(state.recovery, 88);
    expect(state.hrvTrend, 4.5);
    expect(state.weightTrend, -0.3);
  });

  test('copyWith changes one metric without changing the snapshot', () {
    final state = AthleteState(
      profile: AthleteProfile(
        name: 'Neil',
        experienceLevel: 'intermediate',
        ftp: 240,
        maximumHeartRate: 190,
        restingHeartRate: 50,
        weightKg: 72,
        weeklyLoadTarget: 400,
      ),
      updatedAt: DateTime.utc(2026, 8, 25),
      fitness: 60,
      fatigue: 40,
      freshness: 60,
      readiness: 70,
      recovery: 75,
    );

    final updated = state.copyWith(readiness: 82);

    expect(updated.readiness, 82);
    expect(updated.fitness, state.fitness);
    expect(updated.profile, state.profile);
  });
}
