import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftEventGoalRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftEventGoalRepository(database);
  });

  tearDown(() => database.close());

  test('maps a saved goal to the coaching domain and normalises its date',
      () async {
    await repository.saveGoal(
      CoachingEventGoal(
        name: '  Dragon Ride  ',
        eventDate: DateTime(2027, 6, 13, 9, 30),
        distanceKm: 200,
        elevationMetres: 3200,
        priority: 'A',
        target: 'finishStrong',
        terrain: 'mountainous',
        availableDays: 5,
        longRideMinutes: 300,
      ),
    );

    final goal = await repository.getGoal();
    expect(goal?.name, 'Dragon Ride');
    expect(goal?.eventDate, DateTime(2027, 6, 13));
    expect(goal?.distanceKm, 200);
    expect(goal?.availableDays, 5);
    expect(goal?.longRideMinutes, 300);
  });

  test('watch emits deletion without exposing the database row', () async {
    await repository.saveGoal(
      CoachingEventGoal(
        name: 'Club TT',
        eventDate: DateTime(2026, 9, 1),
        distanceKm: 16.1,
        elevationMetres: 100,
        priority: 'B',
        target: 'targetTime',
        terrain: 'flat',
        availableDays: 4,
        longRideMinutes: 180,
      ),
    );

    final values = <CoachingEventGoal?>[];
    final subscription = repository.watchGoal().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    await repository.deleteGoal();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(values.first?.name, 'Club TT');
    expect(values.last, isNull);
  });
}
