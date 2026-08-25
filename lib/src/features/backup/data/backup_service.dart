import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share;

const _backupTables = <String>[
  'activities',
  'activity_samples',
  'athlete_settings',
  'daily_recovery_records',
  'body_measurements',
  'planned_sessions',
  'ftp_estimates',
  'training_preferences',
  'event_goals',
  'nutrition_entries',
  'daily_nutrition_targets',
  'post_ride_feedbacks',
  'saved_foods',
  'strength_profiles',
  'strength_sessions',
  'strength_sets',
];

class BackupResult {
  const BackupResult(this.path, this.recordCount);
  final String path;
  final int recordCount;
}

class RestorePreview {
  const RestorePreview(
      {required this.file,
      required this.createdAt,
      required this.recordCount,
      required this.tables});
  final XFile file;
  final DateTime createdAt;
  final int recordCount;
  final Map<String, List<Map<String, Object?>>> tables;
}

class BackupService {
  const BackupService(this.database);
  final AppDatabase database;

  Future<BackupResult?> exportBackup() async {
    final now = DateTime.now();
    final tables = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final table in _backupTables) {
      final rows = await database.customSelect('SELECT * FROM "$table"').get();
      tables[table] = rows.map((row) => row.data).toList();
      count += rows.length;
    }
    final payload = jsonEncode({
      'format': 'cycle_ready_backup',
      'version': 1,
      'schemaVersion': database.schemaVersion,
      'createdAt': now.toUtc().toIso8601String(),
      'recordCount': count,
      'tables': tables,
    });
    final fileName = 'CycleReady-backup-${_dateName(now)}.json';
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    await share.SharePlus.instance.share(share.ShareParams(
      files: [share.XFile(path, mimeType: 'application/json', name: fileName)],
      subject: 'CycleReady backup',
      text: 'Save this CycleReady backup somewhere safe.',
    ));
    return BackupResult(path, count);
  }

  Future<RestorePreview?> selectBackup() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'CycleReady backup', extensions: ['json']),
    ]);
    if (file == null) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'cycle_ready_backup' ||
        decoded['version'] != 1) {
      throw const FormatException('This is not a supported CycleReady backup.');
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException('The backup does not contain any tables.');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final table in _backupTables) {
      final rawRows = rawTables[table];
      if (rawRows == null) {
        tables[table] = [];
        continue;
      }
      if (rawRows is! List) {
        throw FormatException('Invalid data for $table.');
      }
      final rows = rawRows.map((row) {
        if (row is! Map) throw FormatException('Invalid row in $table.');
        return row.map((key, value) => MapEntry('$key', value));
      }).toList();
      tables[table] = rows;
      count += rows.length;
    }
    final createdAt = DateTime.tryParse('${decoded['createdAt']}');
    if (createdAt == null) {
      throw const FormatException('The backup date is invalid.');
    }
    return RestorePreview(
        file: file,
        createdAt: createdAt.toLocal(),
        recordCount: count,
        tables: tables);
  }

  Future<void> restore(RestorePreview preview) async {
    await database.transaction(() async {
      await database.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in _backupTables.reversed) {
        await database.customStatement('DELETE FROM "$table"');
      }
      for (final table in _backupTables) {
        for (final row in preview.tables[table] ?? const []) {
          if (row.isEmpty) continue;
          final columns =
              row.keys.map((key) => '"${_safeName(key)}"').join(', ');
          final placeholders = List.filled(row.length, '?').join(', ');
          await database.customStatement(
            'INSERT INTO "$table" ($columns) VALUES ($placeholders)',
            row.values.toList(),
          );
        }
      }
    });
  }
}

String _safeName(String value) {
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    throw const FormatException('The backup contains an invalid column name.');
  }
  return value;
}

String _dateName(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
