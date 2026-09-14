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
  Future<CoachingEventGoal?> getGoal() async => _primary(await getGoals());

  @override
  Future<List<CoachingEventGoal>> getGoals() async =>
      (await database.getEventGoals()).map(_toDomain).toList();

  @override
  Stream<CoachingEventGoal?> watchGoal() => watchGoals().map(_primary);

  @override
  Stream<List<CoachingEventGoal>> watchGoals() =>
      database.watchEventGoals().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<void> saveGoal(CoachingEventGoal goal) async {
    final existing = await database.getEventGoals();
    final id = goal.id ??
        existing.fold<int>(
                0, (largest, row) => row.id > largest ? row.id : largest) +
            1;
    await database.saveEventGoal(
      EventGoalsCompanion.insert(
        id: Value(id),
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
  }

  @override
  Future<void> deleteGoal(int id) => database.deleteEventGoal(id);

  CoachingEventGoal _toDomain(EventGoal row) => CoachingEventGoal(
        id: row.id,
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

  CoachingEventGoal? _primary(List<CoachingEventGoal> goals) {
    final upcoming =
        goals.where((goal) => !goal.eventDate.isBefore(DateTime.now())).toList()
          ..sort((left, right) {
            final priority = left.priority.compareTo(right.priority);
            return priority != 0
                ? priority
                : left.eventDate.compareTo(right.eventDate);
          });
    return upcoming.firstOrNull;
  }
}

final eventGoalRepositoryProvider = Provider<EventGoalRepository>(
  (ref) => DriftEventGoalRepository(ref.watch(databaseProvider)),
);
