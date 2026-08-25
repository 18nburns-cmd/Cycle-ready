import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/backup/data/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
  bool busy = false;
  String? message;

  BackupService get service => BackupService(ref.read(databaseProvider));

  Future<void> _backup() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await service.exportBackup();
      if (!mounted || result == null) return;
      setState(() => message =
          'Backup created with ${result.recordCount} records. Choose Files, Drive or another destination in the share panel to keep it safe.');
    } catch (error) {
      if (mounted) setState(() => message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final preview = await service.selectBackup();
      if (!mounted || preview == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace local data?'),
          content: Text(
            'This backup was created on ${preview.createdAt.day}/'
            '${preview.createdAt.month}/${preview.createdAt.year} and contains '
            '${preview.recordCount} records.\n\nRestoring replaces the data currently '
            'stored in CycleReady. Connected-service passwords and API keys are not changed.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore')),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.restore(preview);
      if (!mounted) return;
      setState(() => message =
          'Restore complete. Restart CycleReady to refresh every screen.');
    } catch (error) {
      if (mounted) setState(() => message = 'Restore failed safely: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              CircleAvatar(child: Icon(Icons.cloud_download_outlined)),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Backup and restore',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Protect your locally stored CycleReady data'),
                  ])),
            ]),
            const SizedBox(height: 12),
            const Text(
                'Exports rides, samples, plans, check-ins, nutrition, body measurements and strength history. API keys are never included.'),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(message!),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                onPressed: busy ? null : _backup,
                icon: const Icon(Icons.save_alt),
                label: const Text('Create backup'),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: busy ? null : _restore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              )),
            ]),
          ]),
        ),
      );
}
