import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final intervalsOAuthServiceProvider = Provider<IntervalsOAuthService?>((ref) {
  if (!CloudConfig.fromEnvironment().isConfigured) return null;
  return IntervalsOAuthService(Supabase.instance.client);
});

class IntervalsOAuthService {
  const IntervalsOAuthService(this.client);

  final SupabaseClient client;

  Future<Uri> beginAuthorization() async {
    if (client.auth.currentSession == null) {
      throw StateError('Sign in to CycleReady Cloud first.');
    }
    final response = await client.functions.invoke('intervals-oauth-start');
    final data = response.data;
    final value = data is Map ? data['authorization_url'] : null;
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || uri.scheme != 'https' || uri.host != 'intervals.icu') {
      throw StateError('CycleReady received an invalid authorization link.');
    }
    return uri;
  }

  Future<bool> isConnected() async {
    if (client.auth.currentSession == null) return false;
    final rows = await client
        .from('integrations')
        .select('connection_status, authorization_method')
        .eq('provider', 'intervals_icu')
        .limit(1);
    return rows.isNotEmpty &&
        rows.first['connection_status'] == 'connected' &&
        rows.first['authorization_method'] == 'oauth';
  }
}
