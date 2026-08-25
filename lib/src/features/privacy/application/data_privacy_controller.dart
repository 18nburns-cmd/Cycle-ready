import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share;

final dataPrivacyControllerProvider = Provider(DataPrivacyController.new);

class DataPrivacyController {
  DataPrivacyController(this.ref);
  final Ref ref;

  Future<String?> exportData() async {
    final snapshot = await ref.read(databaseProvider).exportSnapshot();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = 'cycleready-export-$date.json';
    final contents = const JsonEncoder.withIndent('  ').convert(snapshot);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    await File(path).writeAsBytes(
      Uint8List.fromList(utf8.encode(contents)),
      flush: true,
    );
    await share.SharePlus.instance.share(share.ShareParams(
      files: [share.XFile(path, name: fileName, mimeType: 'application/json')],
      subject: 'CycleReady data export',
      text: 'Save this CycleReady data export somewhere safe.',
    ));
    return path;
  }

  Future<void> eraseData() async {
    await ref.read(databaseProvider).eraseAllUserData();
    await ref.read(intervalsIcuServiceProvider).disconnect();
    ref.invalidate(databaseProvider);
  }

  Future<BackupRestoreResult?> restoreData() async {
    const type = XTypeGroup(
      label: 'CycleReady JSON backup',
      extensions: ['json'],
    );
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('This is not a CycleReady backup.');
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    if (snapshot['schemaVersion'] == null || snapshot['activities'] is! List) {
      throw const FormatException('This is not a complete CycleReady backup.');
    }
    await ref.read(databaseProvider).restoreSnapshot(snapshot);
    return BackupRestoreResult(
      path: file.path,
      activities: (snapshot['activities'] as List).length,
      recoveryDays: (snapshot['dailyRecovery'] as List?)?.length ?? 0,
      strengthSessions: (snapshot['strengthSessions'] as List?)?.length ?? 0,
      nutritionEntries: (snapshot['nutritionEntries'] as List?)?.length ?? 0,
    );
  }
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.path,
    required this.activities,
    required this.recoveryDays,
    required this.strengthSessions,
    required this.nutritionEntries,
  });

  final String path;
  final int activities;
  final int recoveryDays;
  final int strengthSessions;
  final int nutritionEntries;
}
