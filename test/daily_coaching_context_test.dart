import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const athlete = AthleteProfile(
    name: 'Neil',
    experienceLevel: 'intermediate',
    ftp: 250,
    maximumHeartRate: 190,
    restingHeartRate: 50,
    weightKg: 72,
    weeklyLoadTarget: 400,
  );

  test('training history confidence requires three recent rides', () {
    final context = DailyCoachingContext(
      generatedAt: DateTime(2026, 8, 24),
      athlete: athlete,
      readinessScore: 72,
      readinessStatus: 'ready',
      fitness: 45,
      fatigue: 50,
      form: -5,
      weeklyLoad: 320,
      recentRides: List.generate(
        3,
        (index) => RecentRideContext(
          startedAt: DateTime(2026, 8, 23 - index),
          title: 'Ride ${index + 1}',
          durationMinutes: 60,
          load: 55,
        ),
      ),
      trainingDaysPerWeek: 4,
      goal: null,
      learnedResponse: null,
    );

    expect(context.hasReliableTrainingHistory, isTrue);
  });

  test('context retains goal phase and learned workout response', () {
    final context = DailyCoachingContext(
      generatedAt: DateTime(2026, 8, 24),
      athlete: athlete,
      readinessScore: 60,
      readinessStatus: 'caution',
      fitness: 45,
      fatigue: 57,
      form: -12,
      weeklyLoad: 370,
      recentRides: const [],
      trainingDaysPerWeek: 4,
      goal: GoalContext(
        name: 'Gran Fondo',
        eventDate: DateTime(2026, 10, 1),
        phase: 'Build',
        daysRemaining: 38,
      ),
      learnedResponse: const LearnedWorkoutResponse(
        workoutType: 'intervals',
        sampleCount: 5,
        completionRate: .8,
        averageLoadRatio: 1.05,
        averageLegFatigue: 6,
      ),
    );

    expect(context.goal?.phase, 'Build');
    expect(context.learnedResponse?.sampleCount, 5);
    expect(context.hasReliableTrainingHistory, isFalse);
  });
}
