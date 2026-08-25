import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_cloud_snapshot_repository.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_dashboard_summary.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_portal_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cloudSnapshotRepositoryProvider =
    Provider<CloudSnapshotRepository?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured) return null;
  return SupabaseCloudSnapshotRepository(Supabase.instance.client);
});

final cloudActivitySampleRepositoryProvider =
    Provider<CloudActivitySampleRepository?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured) return null;
  return SupabaseCloudSnapshotRepository(Supabase.instance.client);
});

final cloudActivitySamplesProvider =
    FutureProvider.family<List<CloudActivitySample>, String>(
  (ref, activityId) async {
    final account = await ref.watch(cloudAccountProvider.future);
    if (account == null) return const [];
    return await ref
            .watch(cloudActivitySampleRepositoryProvider)
            ?.fetchForActivity(activityId) ??
        const [];
  },
);

final cloudSnapshotProvider = FutureProvider<CloudSnapshot?>((ref) async {
  final account = await ref.watch(cloudAccountProvider.future);
  if (account == null) return null;
  return ref.watch(cloudSnapshotRepositoryProvider)?.fetch();
});

final webDashboardSummaryProvider =
    FutureProvider<WebDashboardSummary?>((ref) async {
  final snapshot = await ref.watch(cloudSnapshotProvider.future);
  return snapshot == null ? null : WebDashboardSummary.fromSnapshot(snapshot);
});

final webPortalDataProvider = FutureProvider<WebPortalData?>((ref) async {
  final snapshot = await ref.watch(cloudSnapshotProvider.future);
  return snapshot == null ? null : WebPortalData.fromSnapshot(snapshot);
});
