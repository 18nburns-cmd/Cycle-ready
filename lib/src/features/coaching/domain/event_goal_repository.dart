import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';

abstract interface class EventGoalRepository {
  Future<CoachingEventGoal?> getGoal();
  Stream<CoachingEventGoal?> watchGoal();
  Future<void> saveGoal(CoachingEventGoal goal);
  Future<void> deleteGoal();
}
