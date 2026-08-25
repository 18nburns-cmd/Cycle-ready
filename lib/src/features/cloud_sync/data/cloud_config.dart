import 'package:supabase_flutter/supabase_flutter.dart';

class CloudConfig {
  const CloudConfig({required this.url, required this.publishableKey});

  factory CloudConfig.fromEnvironment() => const CloudConfig(
        url: String.fromEnvironment('CYCLEREADY_SUPABASE_URL'),
        publishableKey:
            String.fromEnvironment('CYCLEREADY_SUPABASE_PUBLISHABLE_KEY'),
      );

  final String url;
  final String publishableKey;

  bool get isConfigured {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
        uri?.host.isNotEmpty == true &&
        publishableKey.trim().isNotEmpty;
  }
}

Future<bool> initializeCloudIfConfigured({
  CloudConfig config = const CloudConfig(
    url: String.fromEnvironment('CYCLEREADY_SUPABASE_URL'),
    publishableKey:
        String.fromEnvironment('CYCLEREADY_SUPABASE_PUBLISHABLE_KEY'),
  ),
}) async {
  if (!config.isConfigured) return false;
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
  return true;
}
