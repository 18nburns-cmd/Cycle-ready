import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_account.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCloudAuthRepository implements CloudAuthRepository {
  const SupabaseCloudAuthRepository(this.client);

  final SupabaseClient client;

  @override
  Stream<CloudAccount?> watchAccount() async* {
    yield _map(client.auth.currentUser);
    yield* client.auth.onAuthStateChange
        .map((event) => _map(event.session?.user));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureAthlete();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    final response =
        await client.auth.signUp(email: email.trim(), password: password);
    if (response.session != null) await _ensureAthlete();
  }

  @override
  Future<void> requestPasswordReset({required String email}) =>
      client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'com.cycleready.app://reset-password',
      );

  @override
  Future<void> updatePassword({required String password}) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> deleteAccount() async {
    final response = await client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Account deletion failed with HTTP ${response.status}.');
    }
    await client.auth.signOut(scope: SignOutScope.local);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  Future<void> _ensureAthlete() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Cloud account is not signed in.');
    await client.from('athletes').upsert({
      'user_id': user.id,
      'name': _defaultName(user),
    }, onConflict: 'user_id', ignoreDuplicates: true);
  }

  static String _defaultName(User user) {
    final metadataName = user.userMetadata?['name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
    final localPart = (user.email ?? 'CycleReady athlete').split('@').first;
    return localPart.trim().isEmpty ? 'CycleReady athlete' : localPart.trim();
  }

  CloudAccount? _map(User? user) => user == null
      ? null
      : CloudAccount(id: user.id, email: user.email ?? 'CycleReady athlete');
}

class DisabledCloudAuthRepository implements CloudAuthRepository {
  const DisabledCloudAuthRepository();

  @override
  Stream<CloudAccount?> watchAccount() => Stream.value(null);

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw const CloudSyncUnavailable('Cloud sync is not configured.');

  @override
  Future<void> signUp({required String email, required String password}) =>
      throw const CloudSyncUnavailable('Cloud sync is not configured.');

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw const CloudSyncUnavailable('Cloud sync is not configured.');

  @override
  Future<void> updatePassword({required String password}) =>
      throw const CloudSyncUnavailable('Cloud sync is not configured.');

  @override
  Future<void> deleteAccount() =>
      throw const CloudSyncUnavailable('Cloud sync is not configured.');

  @override
  Future<void> signOut() async {}
}
