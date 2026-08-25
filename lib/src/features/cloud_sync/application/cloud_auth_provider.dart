import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/supabase_cloud_auth_repository.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cloudConfigProvider = Provider((ref) => CloudConfig.fromEnvironment());

final cloudAuthRepositoryProvider = Provider<CloudAuthRepository>((ref) {
  final config = ref.watch(cloudConfigProvider);
  if (!config.isConfigured) return const DisabledCloudAuthRepository();
  return SupabaseCloudAuthRepository(Supabase.instance.client);
});

final cloudAccountProvider = StreamProvider<CloudAccount?>((ref) {
  return ref.watch(cloudAuthRepositoryProvider).watchAccount();
});
