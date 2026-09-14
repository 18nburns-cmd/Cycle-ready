import 'package:cycle_ready/src/features/offline_sync/data/supabase_mutation_uploader.dart';
import 'package:cycle_ready/src/features/offline_sync/domain/offline_mutation.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/offline_sync/data/drift_offline_mutation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final offlineMutationRepositoryProvider =
    Provider<OfflineMutationRepository>((ref) {
  return DriftOfflineMutationRepository(ref.watch(databaseProvider));
});

final offlineMutationSyncServiceProvider =
    Provider<OfflineMutationSyncService?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured ||
      Supabase.instance.client.auth.currentUser == null) {
    return null;
  }
  return OfflineMutationSyncService(
    ref.watch(offlineMutationRepositoryProvider),
    SupabaseMutationUploader(Supabase.instance.client),
  );
});

class OfflineMutationSyncResult {
  const OfflineMutationSyncResult({
    required this.applied,
    required this.conflicts,
    required this.retries,
  });
  final int applied;
  final int conflicts;
  final int retries;
}

class OfflineMutationSyncService {
  const OfflineMutationSyncService(this.repository, this.uploader);

  final OfflineMutationRepository repository;
  final SupabaseMutationUploader uploader;

  Future<OfflineMutationSyncResult> flush() async {
    var applied = 0;
    var conflicts = 0;
    var retries = 0;
    for (final mutation in await repository.pending()) {
      try {
        final resolution = await uploader.upload(mutation);
        if (resolution == ConflictResolution.conflict) {
          await repository.markConflict(
            mutation.id,
            'The server record changed after this device last observed it.',
          );
          conflicts++;
        } else {
          await repository.markApplied(mutation.id);
          applied++;
        }
      } catch (error) {
        await repository.markRetry(mutation.id, '$error');
        retries++;
      }
    }
    return OfflineMutationSyncResult(
      applied: applied,
      conflicts: conflicts,
      retries: retries,
    );
  }
}
