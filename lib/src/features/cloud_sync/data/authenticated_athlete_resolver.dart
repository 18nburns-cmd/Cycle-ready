import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the only athlete owned by the current account without relying on
/// the database containing only one athlete globally.
class AuthenticatedAthleteResolver {
  const AuthenticatedAthleteResolver(this.client);

  final SupabaseClient client;

  Future<String> resolveId() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Cloud account is not signed in.');
    final athlete = await client
        .from('athletes')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (athlete == null) {
      throw StateError('The signed-in account has no athlete profile.');
    }
    return '${athlete['id']}';
  }
}
