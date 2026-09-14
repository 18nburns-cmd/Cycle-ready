import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_sync_controller.dart';

final eventGoalProvider = StreamProvider<CoachingEventGoal?>(
  (ref) => ref.watch(eventGoalRepositoryProvider).watchGoal(),
);

final eventGoalsProvider = StreamProvider<List<CoachingEventGoal>>(
  (ref) => ref.watch(eventGoalRepositoryProvider).watchGoals(),
);

final eventGoalControllerProvider = Provider(EventGoalController.new);

class EventGoalController {
  const EventGoalController(this.ref);
  final Ref ref;

  Future<void> save({
    int? id,
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
            id: id,
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
    await _syncIfSignedIn();
  }

  Future<void> delete(int id) async {
    await ref.read(eventGoalRepositoryProvider).deleteGoal(id);
    await _syncIfSignedIn();
  }

  Future<void> _syncIfSignedIn() async {
    if (await ref.read(cloudAccountProvider.future) != null) {
      await ref.read(cloudSyncControllerProvider.notifier).upload();
    }
  }
}
