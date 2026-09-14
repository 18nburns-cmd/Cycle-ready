import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/authenticated_athlete_resolver.dart';

class SupabasePushTokenRepository {
  const SupabasePushTokenRepository(this.client);

  final SupabaseClient client;

  Future<void> register(String token) async {
    final user = client.auth.currentUser;
    if (user == null || token.trim().isEmpty) return;
    final athleteId = await AuthenticatedAthleteResolver(client).resolveId();
    await client.from('device_push_tokens').upsert({
      'athlete_id': athleteId,
      'user_id': user.id,
      'token': token,
      'platform': 'android',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> unregisterCurrentAccount() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('device_push_tokens').delete().eq('user_id', user.id);
  }
}
