import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';

abstract interface class EventGoalRepository {
  Future<CoachingEventGoal?> getGoal();
  Future<List<CoachingEventGoal>> getGoals();
  Stream<CoachingEventGoal?> watchGoal();
  Stream<List<CoachingEventGoal>> watchGoals();
  Future<void> saveGoal(CoachingEventGoal goal);
  Future<void> deleteGoal(int id);
}
