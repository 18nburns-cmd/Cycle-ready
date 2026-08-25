import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_context.dart';
import 'package:cycle_ready/src/features/coaching/domain/event_periodisation.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_athlete_learning_repository.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyCoachingContextProvider =
    FutureProvider<DailyCoachingContext>((ref) async {
  final athlete = await ref.watch(athleteProfileProvider.future);
  final rides = await ref.watch(activitiesProvider.future);
  final goal = await ref.watch(eventGoalRepositoryProvider).getGoal();
  final sessions = ref.watch(plannedSessionRepositoryProvider);
  final preferences = await sessions.getPreferences();
  final planned = await sessions.watchDay(DateTime.now()).first;
  final learned = planned == null
      ? null
      : await ref
          .watch(athleteLearningRepositoryProvider)
          .getResponse(planned.sessionType);
  final readiness = ref.watch(todayReadinessProvider);
  final metrics = ref.watch(fitnessMetricsProvider);
  final now = DateTime.now();
  final recentCutoff = now.subtract(const Duration(days: 7));
  final recent = rides
      .where((ride) => ride.startedAt.isAfter(recentCutoff))
      .map(
        (ride) => RecentRideContext(
          startedAt: ride.startedAt,
          title: ride.title,
          durationMinutes: (ride.durationSeconds / 60).round(),
          load: ride.trainingLoad ?? 0,
        ),
      )
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  return DailyCoachingContext(
    generatedAt: now,
    athlete: athlete,
    readinessScore: readiness.score,
    readinessStatus: readiness.band.name,
    fitness: metrics.fitness,
    fatigue: metrics.fatigue,
    form: metrics.form,
    weeklyLoad: metrics.weeklyLoad,
    recentRides: List.unmodifiable(recent),
    trainingDaysPerWeek: preferences.daysPerWeek,
    goal: goal == null
        ? null
        : GoalContext(
            name: goal.name,
            eventDate: goal.eventDate,
            phase: eventPhaseLabel(eventPhaseFor(now, goal.eventDate)),
            daysRemaining: goal.eventDate.difference(now).inDays.clamp(0, 9999),
          ),
    learnedResponse: learned == null
        ? null
        : LearnedWorkoutResponse(
            workoutType: planned!.sessionType,
            sampleCount: learned.sampleCount,
            completionRate: learned.completionRate,
            averageLoadRatio: learned.averageLoadRatio,
            averageLegFatigue: learned.averageLegFatigue,
          ),
  );
});
