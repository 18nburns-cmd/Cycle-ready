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
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await client.auth.signUp(email: email.trim(), password: password);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

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
  Future<void> signOut() async {}
}
