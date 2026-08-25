import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';

class WorkoutDeliveryResult {
  const WorkoutDeliveryResult({
    required this.provider,
    required this.delivered,
  });

  final String provider;
  final int delivered;
}

abstract interface class WorkoutDeliveryProvider {
  String get id;
  Future<WorkoutDeliveryResult> deliver(List<StructuredWorkout> workouts);
}

class MockWorkoutDeliveryProvider implements WorkoutDeliveryProvider {
  final deliveredWorkouts = <StructuredWorkout>[];

  @override
  String get id => 'mock';

  @override
  Future<WorkoutDeliveryResult> deliver(
      List<StructuredWorkout> workouts) async {
    deliveredWorkouts.addAll(workouts);
    return WorkoutDeliveryResult(provider: id, delivered: workouts.length);
  }
}
