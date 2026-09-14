import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_cloud_snapshot_repository.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_relational_coaching_repository.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_dashboard_summary.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_portal_data.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/relational_coaching_data.dart';
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

final relationalCoachingRepositoryProvider =
    Provider<RelationalCoachingRepository?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured) return null;
  return SupabaseRelationalCoachingRepository(Supabase.instance.client);
});

final relationalCoachingDataProvider =
    FutureProvider<RelationalCoachingData?>((ref) async {
  final account = await ref.watch(cloudAccountProvider.future);
  if (account == null) return null;
  return ref.watch(relationalCoachingRepositoryProvider)?.fetch();
});

final authoritativeCoachingDecisionProvider =
    FutureProvider<AuthoritativeCoachingDecision?>((ref) async {
  return (await ref.watch(relationalCoachingDataProvider.future))
      ?.latestDecision;
});

final webDashboardSummaryProvider =
    FutureProvider<WebDashboardSummary?>((ref) async {
  final portal = await ref.watch(webPortalDataProvider.future);
  return portal == null ? null : WebDashboardSummary.fromPortal(portal);
});

final webPortalDataProvider = FutureProvider<WebPortalData?>((ref) async {
  final data = await ref.watch(relationalCoachingDataProvider.future);
  return data == null ? null : WebPortalData.fromRelational(data);
});
