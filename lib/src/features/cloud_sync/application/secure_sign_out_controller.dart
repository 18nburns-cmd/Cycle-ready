import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/notifications/data/supabase_push_token_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final secureSignOutControllerProvider = Provider(SecureSignOutController.new);

class SecureSignOutController {
  const SecureSignOutController(this.ref);

  final Ref ref;

  Future<void> signOut() async {
    final configured = ref.read(cloudConfigProvider).isConfigured;
    if (configured) {
      await SupabasePushTokenRepository(Supabase.instance.client)
          .unregisterCurrentAccount();
    }
    await ref.read(databaseProvider).eraseAllUserData();
    await ref.read(intervalsIcuServiceProvider).disconnect();
    await ref.read(cloudAuthRepositoryProvider).signOut();
    ref.invalidate(databaseProvider);
  }

  Future<void> deleteAccount() async {
    await ref.read(cloudAuthRepositoryProvider).deleteAccount();
    await ref.read(databaseProvider).eraseAllUserData();
    await ref.read(intervalsIcuServiceProvider).disconnect();
    ref.invalidate(databaseProvider);
  }
}
