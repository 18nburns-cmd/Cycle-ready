import 'dart:io';

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('schema 17 fixture upgrades without losing athlete or ride data',
      () async {
    final fixture = await _createFixture(version: 17);
    addTearDown(() => fixture.parent.delete(recursive: true));

    final database = AppDatabase(NativeDatabase(fixture));
    addTearDown(database.close);
    final athlete = await database.getAthleteSettings();
    final rides = await database.getActivities();

    expect(athlete.athleteName, 'Neil');
    expect(athlete.ftp, 247);
    expect(athlete.weightKg, 72.4);
    expect(athlete.bikeDetails, isEmpty);
    expect(athlete.hasIndoorTrainer, isTrue);
    expect(athlete.trainingLocation, isEmpty);
    expect(athlete.ridingSafetyProfile, 'balanced');
    expect(rides.single.id, 'fixture-ride');
    expect(rides.single.averagePower, 211);
    expect(await _userVersion(database), 20);
  });

  test('schema 19 fixture preserves location and adds weather safety default',
      () async {
    final fixture = await _createFixture(version: 19);
    addTearDown(() => fixture.parent.delete(recursive: true));

    final database = AppDatabase(NativeDatabase(fixture));
    addTearDown(database.close);
    final athlete = await database.getAthleteSettings();

    expect(athlete.trainingLocation, 'NE1 1AA');
    expect(athlete.ridingSafetyProfile, 'balanced');
    expect((await database.getActivities()).single.title, 'Fixture tempo');
    expect(await _userVersion(database), 20);
  });
}

Future<File> _createFixture({required int version}) async {
  final directory =
      await Directory.systemTemp.createTemp('cycle-ready-v$version-');
  final file =
      File('${directory.path}${Platform.pathSeparator}cycle_ready.sqlite');
  final seed = AppDatabase(NativeDatabase(file));
  await seed.saveAthleteSettings(
    AthleteSettingsCompanion.insert(
      athleteName: const Value('Neil'),
      ftp: const Value(247),
      weightKg: const Value(72.4),
      trainingLocation: const Value('NE1 1AA'),
      ridingSafetyProfile: const Value('cautious'),
    ),
  );
  await seed.saveActivity(
    ActivitiesCompanion.insert(
      id: 'fixture-ride',
      title: const Value('Fixture tempo'),
      source: 'intervalsIcu',
      startedAt: DateTime(2026, 7, 10, 18),
      durationSeconds: 3600,
      distanceMetres: 32000,
      averagePower: const Value(211),
      trainingLoad: const Value(68),
    ),
    const [],
  );
  await seed.close();

  final raw = sqlite.sqlite3.open(file.path);
  try {
    if (version < 20) {
      raw.execute(
        'ALTER TABLE athlete_settings DROP COLUMN riding_safety_profile',
      );
    }
    if (version < 19) {
      raw.execute('ALTER TABLE athlete_settings DROP COLUMN training_location');
    }
    if (version < 18) {
      for (final column in const [
        'bike_details',
        'equipment',
        'has_power_meter',
        'has_indoor_trainer',
        'preferred_ride_time_minutes',
        'nutrition_preferences',
        'injury_history',
      ]) {
        raw.execute('ALTER TABLE athlete_settings DROP COLUMN $column');
      }
    }
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.dispose();
  }
  return file;
}

Future<int> _userVersion(AppDatabase database) async {
  final result = await database.customSelect('PRAGMA user_version').getSingle();
  return result.read<int>('user_version');
}
