import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';

class DailyCoachingContext {
  const DailyCoachingContext({
    required this.generatedAt,
    required this.athlete,
    required this.readinessScore,
    required this.readinessStatus,
    required this.fitness,
    required this.fatigue,
    required this.form,
    required this.weeklyLoad,
    required this.recentRides,
    required this.trainingDaysPerWeek,
    required this.goal,
    required this.learnedResponse,
  });

  final DateTime generatedAt;
  final AthleteProfile athlete;
  final int readinessScore;
  final String readinessStatus;
  final double fitness;
  final double fatigue;
  final double form;
  final double weeklyLoad;
  final List<RecentRideContext> recentRides;
  final int trainingDaysPerWeek;
  final GoalContext? goal;
  final LearnedWorkoutResponse? learnedResponse;

  bool get hasReliableTrainingHistory => recentRides.length >= 3;
}

class RecentRideContext {
  const RecentRideContext({
    required this.startedAt,
    required this.title,
    required this.durationMinutes,
    required this.load,
  });

  final DateTime startedAt;
  final String title;
  final int durationMinutes;
  final int load;
}

class GoalContext {
  const GoalContext({
    required this.name,
    required this.eventDate,
    required this.phase,
    required this.daysRemaining,
  });

  final String name;
  final DateTime eventDate;
  final String phase;
  final int daysRemaining;
}

class LearnedWorkoutResponse {
  const LearnedWorkoutResponse({
    required this.workoutType,
    required this.sampleCount,
    required this.completionRate,
    required this.averageLoadRatio,
    required this.averageLegFatigue,
  });

  final String workoutType;
  final int sampleCount;
  final double completionRate;
  final double averageLoadRatio;
  final double averageLegFatigue;
}
