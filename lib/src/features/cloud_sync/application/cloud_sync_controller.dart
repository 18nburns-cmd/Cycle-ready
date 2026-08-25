import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CloudSyncState {
  const CloudSyncState({
    this.syncing = false,
    this.lastUpload,
    this.conflict = false,
    this.message = 'Sign in to protect and share your CycleReady data.',
  });

  final bool syncing;
  final DateTime? lastUpload;
  final bool conflict;
  final String message;
}

final cloudSyncControllerProvider =
    AsyncNotifierProvider<CloudSyncController, CloudSyncState>(
  CloudSyncController.new,
);

class CloudSyncController extends AsyncNotifier<CloudSyncState> {
  static const _lastRemoteUpdateKey = 'cycle_ready_last_remote_snapshot';
  final _storage = const FlutterSecureStorage();

  @override
  Future<CloudSyncState> build() async {
    final stored = await _storage.read(key: _lastRemoteUpdateKey);
    return CloudSyncState(
      lastUpload: stored == null ? null : DateTime.tryParse(stored)?.toLocal(),
    );
  }

  Future<void> upload() async {
    final previous = state.valueOrNull ?? const CloudSyncState();
    state = AsyncData(CloudSyncState(
      syncing: true,
      lastUpload: previous.lastUpload,
      message: 'Uploading securely to CycleReady cloudâ€¦',
    ));
    try {
      final account = await ref.read(cloudAccountProvider.future);
      final repository = ref.read(cloudSnapshotRepositoryProvider);
      if (account == null || repository == null) {
        throw StateError('Sign in before synchronising CycleReady data.');
      }
      final stored = await _storage.read(key: _lastRemoteUpdateKey);
      final service = CloudSyncService(
        database: ref.read(databaseProvider),
        repository: repository,
        deviceName: 'CycleReady Android',
      );
      final outcome = await service.uploadIfSafe(
        lastKnownRemoteUpdate:
            stored == null ? null : DateTime.tryParse(stored),
      );
      if (outcome == CloudSyncOutcome.remoteIsNewer) {
        state = AsyncData(CloudSyncState(
          lastUpload: previous.lastUpload,
          conflict: true,
          message:
              'A newer cloud copy exists. Nothing was overwritten; review it on the web before replacing either copy.',
        ));
        return;
      }
      final remote = await repository.fetch();
      final updatedAt = remote?.updatedAt ?? DateTime.now().toUtc();
      await _storage.write(
        key: _lastRemoteUpdateKey,
        value: updatedAt.toUtc().toIso8601String(),
      );
      ref.invalidate(cloudSnapshotProvider);
      state = AsyncData(CloudSyncState(
        lastUpload: updatedAt.toLocal(),
        message: 'Your latest CycleReady data is available on the web.',
      ));
    } catch (error) {
      state = AsyncData(CloudSyncState(
        lastUpload: previous.lastUpload,
        message: 'Cloud upload failed safely: $error. You can retry now.',
      ));
    }
  }
}
