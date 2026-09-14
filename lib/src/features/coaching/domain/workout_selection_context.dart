import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';

enum WorkoutSelectionGoal { balanced, ftp, endurance, event }

class WorkoutRecoveryContext {
  const WorkoutRecoveryContext({
    required this.readiness,
    required this.confidence,
    required this.sleepScore,
    required this.hrvStatus,
    required this.restingHeartRateStatus,
    required this.recoveryHours,
    required this.illnessOrInjury,
  });

  final int readiness;
  final double confidence;
  final double? sleepScore;
  final double? hrvStatus;
  final double? restingHeartRateStatus;
  final int recoveryHours;
  final bool illnessOrInjury;
}

class RecentWorkoutLoad {
  const RecentWorkoutLoad({
    required this.at,
    required this.family,
    required this.load,
    required this.completed,
  });

  final DateTime at;
  final WorkoutFamily family;
  final int load;
  final bool completed;
}

class WorkoutSelectionContext {
  WorkoutSelectionContext({
    required this.forDay,
    required this.athleteState,
    required this.goal,
    required this.phase,
    required this.weeklyIntent,
    required this.recovery,
    required Set<WorkoutEquipment> availableEquipment,
    required List<RecentWorkoutLoad> recentLoad,
    required List<CyclingAvailability> availability,
    required Map<WorkoutFamily, WorkoutResponseSnapshot> learnedResponses,
    this.weather,
  })  : recentLoad = List.unmodifiable(recentLoad),
        availability = List.unmodifiable(availability),
        availableEquipment = Set.unmodifiable(availableEquipment),
        learnedResponses = Map.unmodifiable(learnedResponses);

  final DateTime forDay;
  final AthleteState athleteState;
  final WorkoutSelectionGoal goal;
  final WorkoutCataloguePhase phase;
  final AdaptationTarget weeklyIntent;
  final WorkoutRecoveryContext recovery;
  final List<RecentWorkoutLoad> recentLoad;
  final List<CyclingAvailability> availability;
  final Set<WorkoutEquipment> availableEquipment;
  final RideWeather? weather;
  final Map<WorkoutFamily, WorkoutResponseSnapshot> learnedResponses;
}
