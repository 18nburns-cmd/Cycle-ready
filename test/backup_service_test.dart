import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/backup/data/backup_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restore replaces local records from a validated preview', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.athleteSettings).insert(
          AthleteSettingsCompanion.insert(ftp: const Value(190)),
        );
    final preview = RestorePreview(
      file: XFile('unused.json'),
      createdAt: DateTime(2026, 8, 13),
      recordCount: 1,
      tables: {
        'athlete_settings': [
          {
            'id': 1,
            'ftp': 245,
            'maximum_heart_rate': 190,
            'resting_heart_rate': 50,
            'weight_kg': 70.0,
            'weekly_load_target': 350,
          },
        ],
      },
    );

    await BackupService(database).restore(preview);

    expect(
        (await database.select(database.athleteSettings).getSingle()).ftp, 245);
  });

  test('a failed restore rolls back instead of erasing existing data',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.athleteSettings).insert(
          AthleteSettingsCompanion.insert(ftp: const Value(210)),
        );
    final preview = RestorePreview(
      file: XFile('unused.json'),
      createdAt: DateTime(2026, 8, 13),
      recordCount: 1,
      tables: {
        'athlete_settings': [
          {'not_a_column': 1},
        ],
      },
    );

    await expectLater(
        BackupService(database).restore(preview), throwsA(anything));
    expect(
        (await database.select(database.athleteSettings).getSingle()).ftp, 210);
  });
}
