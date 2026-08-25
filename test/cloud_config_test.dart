import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud configuration requires a URL and publishable key', () {
    expect(const CloudConfig(url: '', publishableKey: '').isConfigured, false);
    expect(
      const CloudConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      ).isConfigured,
      true,
    );
    expect(
      const CloudConfig(url: 'not a url', publishableKey: 'key').isConfigured,
      false,
    );
  });

  test('missing configuration leaves cloud disabled without throwing',
      () async {
    expect(
      await initializeCloudIfConfigured(
        config: const CloudConfig(url: '', publishableKey: ''),
      ),
      false,
    );
  });
}
