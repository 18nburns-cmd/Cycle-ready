import 'package:cycle_ready/src/features/privacy/application/data_privacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DataPrivacyScreen extends ConsumerStatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  ConsumerState<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends ConsumerState<DataPrivacyScreen> {
  bool working = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Data & privacy'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your health data stays on this phone',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CycleReady stores imported rides, heart and sleep '
                      'summaries, check-ins, body measurements and plans in '
                      'its local database. Intervals.icu credentials are held '
                      'in encrypted device storage.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                enabled: !working,
                contentPadding: const EdgeInsets.all(18),
                leading: const CircleAvatar(
                  child: Icon(Icons.download_outlined),
                ),
                title: const Text(
                  'Export my data',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Save a readable JSON copy of all CycleReady records.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _export,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                enabled: !working,
                contentPadding: const EdgeInsets.all(18),
                leading: const CircleAvatar(
                  child: Icon(Icons.restore),
                ),
                title: const Text(
                  'Restore from backup',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Validate and restore a CycleReady JSON export. Current local records will be replaced.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _confirmRestore,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                enabled: !working,
                contentPadding: const EdgeInsets.all(18),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                title: Text(
                  'Erase local data',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: const Text(
                  'Permanently removes local health data and disconnects '
                  'Intervals.icu. External services are not changed.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _confirmErase,
              ),
            ),
            if (working) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            Text(
              'CycleReady provides wellness and training guidance, not '
              'medical diagnosis. Export files can contain sensitive health '
              'information—store them securely.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Future<void> _export() async {
    setState(() => working = true);
    try {
      final path = await ref.read(dataPrivacyControllerProvider).exportData();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CycleReady data exported to $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _confirmErase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all local data?'),
        content: const Text(
          'This permanently deletes your rides, samples, recovery history, '
          'check-ins, weight, FTP estimates and training plans from this '
          'phone. Export first if you want a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => working = true);
    await ref.read(dataPrivacyControllerProvider).eraseData();
    if (!mounted) return;
    context.go('/');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local CycleReady data erased.')),
    );
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore CycleReady backup?'),
        content: const Text(
          'The selected backup will replace the records currently stored in '
          'CycleReady. Connected-service credentials are not changed. Invalid '
          'files are rejected before any current data is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => working = true);
    try {
      final result =
          await ref.read(dataPrivacyControllerProvider).restoreData();
      if (!mounted || result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Restored ${result.activities} rides, ${result.recoveryDays} recovery days, '
          '${result.strengthSessions} strength sessions and '
          '${result.nutritionEntries} nutrition entries.',
        ),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed safely: $error')),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}
