import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_sync_controller.dart';
import 'package:cycle_ready/src/features/cloud_sync/presentation/cloud_account_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloudSyncCard extends ConsumerWidget {
  const CloudSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudConfigProvider).isConfigured) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(cloudAccountProvider).valueOrNull;
    final sync = ref.watch(cloudSyncControllerProvider);
    final value = sync.valueOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.cloud_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CycleReady web',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text('Secure phone-to-web synchronisation'),
                    ],
                  ),
                ),
                const CloudAccountButton(),
              ],
            ),
            const SizedBox(height: 12),
            Text(sync.hasError
                ? 'Cloud upload failed safely: ${sync.error}'
                : value?.message ?? 'Preparing cloud syncâ€¦'),
            if (value?.lastUpload != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last uploaded ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value!.lastUpload!))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: account == null || value?.syncing == true
                    ? null
                    : () =>
                        ref.read(cloudSyncControllerProvider.notifier).upload(),
                icon: value?.syncing == true
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(account == null ? 'Sign in first' : 'Upload now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
