import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('health sync cannot overwrite a saved check-in', () async {
    final day = DateTime(2026, 7, 27);
    await database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: day,
      fatigue: const Value(5),
      soreness: const Value(4),
      stress: const Value(2),
      motivation: const Value(1),
    ));

    await database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: day,
      sleepMinutes: const Value(450),
      restingHeartRate: const Value(48),
      hrvMilliseconds: const Value(55),
    ));

    final saved = await database.recoveryForDay(day);
    expect(saved!.fatigue, 5);
    expect(saved.soreness, 4);
    expect(saved.stress, 2);
    expect(saved.motivation, 1);
    expect(saved.sleepMinutes, 450);
  });

  test('Intervals HR update cannot overwrite check-in or sleep', () async {
    final day = DateTime(2026, 7, 27);
    await database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: day,
      sleepMinutes: const Value(420),
      fatigue: const Value(1),
      soreness: const Value(2),
      stress: const Value(3),
      motivation: const Value(4),
    ));
    await database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: day,
      restingHeartRate: const Value(44),
    ));

    final saved = await database.recoveryForDay(day);
    expect(saved!.restingHeartRate, 44);
    expect(saved.sleepMinutes, 420);
    expect(saved.fatigue, 1);
    expect(saved.motivation, 4);
  });
}
