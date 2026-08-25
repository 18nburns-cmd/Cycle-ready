import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PlannedSessionRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPlannedSessionRepository(database);
  });

  tearDown(() => database.close());

  test('stores, watches and deletes a planned session through repository',
      () async {
    final day = DateTime(2026, 8, 26, 18);
    await repository.save(PlannedSessionWrite(
      day: day,
      sessionType: 'tempo',
      title: 'Tempo 3 x 12 min',
      durationMinutes: 75,
      targetLoad: 82,
      prescription: '3 x 12 min at 88% FTP',
      origin: 'adaptive',
      adaptationReason: 'Build sustained power.',
    ));

    final stored = await repository.watchDay(day).first;
    expect(stored?.day, DateTime(2026, 8, 26));
    expect(stored?.title, 'Tempo 3 x 12 min');
    expect(stored?.origin, 'adaptive');

    await repository.deleteDay(day);
    expect(await repository.watchDay(day).first, isNull);
  });

  test('stores training preferences without exposing Drift companions',
      () async {
    await repository.savePreferences(const TrainingPreferencesWrite(
      goal: 'climbing',
      daysPerWeek: 5,
      longRideWeekday: 7,
      availabilityJson: '[{"weekday":1}]',
    ));

    final stored = await repository.getPreferences();
    expect(stored.goal, 'climbing');
    expect(stored.daysPerWeek, 5);
    expect(stored.availabilityJson, '[{"weekday":1}]');
  });

  test('adaptive deletion preserves manually planned sessions', () async {
    final start = DateTime(2026, 8, 26);
    await repository.save(PlannedSessionWrite(
      day: start,
      sessionType: 'endurance',
      title: 'Adaptive endurance',
      durationMinutes: 60,
      targetLoad: 45,
      origin: 'adaptive',
    ));
    await repository.save(PlannedSessionWrite(
      day: start.add(const Duration(days: 1)),
      sessionType: 'rest',
      title: 'Family day',
      durationMinutes: 0,
      targetLoad: 0,
    ));

    await repository.deleteAdaptive(
      start,
      start.add(const Duration(days: 7)),
    );

    final remaining = await repository.getRange(
      start,
      start.add(const Duration(days: 7)),
    );
    expect(remaining.map((value) => value.title), ['Family day']);
  });
}
