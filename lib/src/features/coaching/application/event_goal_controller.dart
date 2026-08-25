import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventGoalProvider = StreamProvider<CoachingEventGoal?>(
  (ref) => ref.watch(eventGoalRepositoryProvider).watchGoal(),
);

final eventGoalControllerProvider = Provider(EventGoalController.new);

class EventGoalController {
  const EventGoalController(this.ref);
  final Ref ref;

  Future<void> save({
    required String name,
    required DateTime eventDate,
    required double distanceKm,
    required int elevationMetres,
    required String priority,
    required String target,
    required String terrain,
    required int availableDays,
    required int longRideMinutes,
  }) async {
    await ref.read(eventGoalRepositoryProvider).saveGoal(
          CoachingEventGoal(
            name: name.trim(),
            eventDate: DateTime(eventDate.year, eventDate.month, eventDate.day),
            distanceKm: distanceKm,
            elevationMetres: elevationMetres,
            priority: priority,
            target: target,
            terrain: terrain,
            availableDays: availableDays,
            longRideMinutes: longRideMinutes,
          ),
        );
    final current =
        await ref.read(plannedSessionRepositoryProvider).getPreferences();
    await ref.read(plannedSessionControllerProvider).savePreferences(
          goal: TrainingGoal.event,
          daysPerWeek: availableDays,
          longRideWeekday: current.longRideWeekday,
        );
  }

  Future<void> delete() => ref.read(eventGoalRepositoryProvider).deleteGoal();
}
