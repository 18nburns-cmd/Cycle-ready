import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_reconciliation.dart';

class WorkoutDeliveryResult {
  const WorkoutDeliveryResult({
    required this.provider,
    required this.delivered,
    this.reconciliation = const [],
  });

  final String provider;
  final int delivered;
  final List<WorkoutReconciliationResult> reconciliation;
}

abstract interface class WorkoutDeliveryProvider {
  String get id;
  Future<WorkoutDeliveryResult> deliver(List<StructuredWorkout> workouts);
}

abstract interface class ReconcilingWorkoutDeliveryProvider
    implements WorkoutDeliveryProvider {
  Future<WorkoutDeliveryResult> reconcile(
    List<StructuredWorkout> workouts, {
    required List<String> ownedExternalIds,
    bool force = false,
  });
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
