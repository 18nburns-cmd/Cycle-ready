import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:cycle_ready/src/features/coaching/domain/event_goal_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriftEventGoalRepository implements EventGoalRepository {
  const DriftEventGoalRepository(this.database);

  final AppDatabase database;

  @override
  Future<CoachingEventGoal?> getGoal() async =>
      _toDomain(await database.getEventGoal());

  @override
  Stream<CoachingEventGoal?> watchGoal() =>
      database.watchEventGoal().map(_toDomain);

  @override
  Future<void> saveGoal(CoachingEventGoal goal) => database.saveEventGoal(
        EventGoalsCompanion.insert(
          id: const Value(1),
          name: goal.name.trim(),
          eventDate: DateTime(
            goal.eventDate.year,
            goal.eventDate.month,
            goal.eventDate.day,
          ),
          distanceKm: goal.distanceKm,
          elevationMetres: goal.elevationMetres,
          priority: Value(goal.priority),
          target: Value(goal.target),
          terrain: Value(goal.terrain),
          availableDays: Value(goal.availableDays),
          longRideMinutes: Value(goal.longRideMinutes),
        ),
      );

  @override
  Future<void> deleteGoal() => database.deleteEventGoal();

  CoachingEventGoal? _toDomain(EventGoal? row) => row == null
      ? null
      : CoachingEventGoal(
          name: row.name,
          eventDate: row.eventDate,
          distanceKm: row.distanceKm,
          elevationMetres: row.elevationMetres,
          priority: row.priority,
          target: row.target,
          terrain: row.terrain,
          availableDays: row.availableDays,
          longRideMinutes: row.longRideMinutes,
        );
}

final eventGoalRepositoryProvider = Provider<EventGoalRepository>(
  (ref) => DriftEventGoalRepository(ref.watch(databaseProvider)),
);
