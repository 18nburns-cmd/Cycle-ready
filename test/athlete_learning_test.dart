import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('learns incremental averages from workout outcomes', () {
    var profile = const WorkoutResponseSnapshot();
    profile = updateWorkoutResponse(
      previous: profile,
      compliance: assessWorkoutCompliance(
        plannedLoad: 80,
        plannedMinutes: 60,
        actualLoad: 80,
        actualMinutes: 60,
      ),
      perceivedEffort: 7,
      legFatigue: 2,
    );
    profile = updateWorkoutResponse(
      previous: profile,
      compliance: assessWorkoutCompliance(
        plannedLoad: 80,
        plannedMinutes: 60,
        actualLoad: 120,
        actualMinutes: 75,
      ),
      perceivedEffort: 9,
      legFatigue: 4,
    );

    expect(profile.sampleCount, 2);
    expect(profile.completionRate, 1);
    expect(profile.averageLoadRatio, 1.25);
    expect(profile.averagePerceivedEffort, 8);
    expect(profile.averageLegFatigue, 3);
  });

  test('produces a recovery warning after repeated costly sessions', () {
    final profile = WorkoutResponseSnapshot(
      sampleCount: 4,
      averageLoadRatio: 1.28,
      averageDurationRatio: 1.05,
      completionRate: 1,
      feedbackSamples: 4,
      averagePerceivedEffort: 8.5,
      averageLegFatigue: 4.2,
    );
    expect(profile.coachingInsight, contains('extra recovery protection'));
  });

  test('withholds a strong conclusion while baseline is forming', () {
    const profile = WorkoutResponseSnapshot(sampleCount: 2);
    expect(profile.coachingInsight, contains('establishing'));
  });
}
