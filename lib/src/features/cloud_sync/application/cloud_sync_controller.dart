import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_sync_service.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_planned_session_sync_repository.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_event_goal_sync_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/offline_sync/application/offline_mutation_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudSyncState {
  const CloudSyncState({
    this.syncing = false,
    this.lastUpload,
    this.message = 'Sign in to synchronise CycleReady relational data.',
  });

  final bool syncing;
  final DateTime? lastUpload;
  final String message;
}

final cloudSyncControllerProvider =
    AsyncNotifierProvider<CloudSyncController, CloudSyncState>(
  CloudSyncController.new,
);

class CloudSyncController extends AsyncNotifier<CloudSyncState> {
  @override
  Future<CloudSyncState> build() async => const CloudSyncState();

  Future<void> upload() async {
    final previous = state.valueOrNull ?? const CloudSyncState();
    state = AsyncData(CloudSyncState(
      syncing: true,
      lastUpload: previous.lastUpload,
      message: 'Uploading securely to CycleReady cloudâ€¦',
    ));
    try {
      final account = await ref.read(cloudAccountProvider.future);
      final sampleRepository = ref.read(cloudActivitySampleRepositoryProvider);
      if (account == null || sampleRepository == null) {
        throw StateError('Sign in before synchronising CycleReady data.');
      }
      final service = CloudSyncService(
        database: ref.read(databaseProvider),
        repository: ref.read(cloudSnapshotRepositoryProvider)!,
        sampleRepository: sampleRepository,
        deviceName: 'CycleReady Android',
      );
      await service.uploadDetailedActivitySamples();
      final events = await ref.read(eventGoalRepositoryProvider).getGoals();
      await SupabaseEventGoalSyncRepository(Supabase.instance.client)
          .replaceEvents(events);
      final now = DateTime.now();
      final futureSessions =
          await ref.read(databaseProvider).getPlannedSessions(
                DateTime(now.year, now.month, now.day),
                DateTime(now.year, now.month, now.day + 42),
              );
      await SupabasePlannedSessionSyncRepository(Supabase.instance.client)
          .replaceFuture(futureSessions);
      final mutationResult =
          await ref.read(offlineMutationSyncServiceProvider)?.flush();
      final conflicts = mutationResult?.conflicts ?? 0;
      final updatedAt = DateTime.now();
      ref.invalidate(relationalCoachingDataProvider);
      state = AsyncData(CloudSyncState(
        lastUpload: updatedAt,
        message: conflicts == 0
            ? 'Relational data and ride samples are synchronised.'
            : '$conflicts cloud change requires review.',
      ));
    } catch (error) {
      state = AsyncData(CloudSyncState(
        lastUpload: previous.lastUpload,
        message: 'Cloud upload failed safely: $error. You can retry now.',
      ));
    }
  }
}
