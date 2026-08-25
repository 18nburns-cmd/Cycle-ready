import 'package:cycle_ready/src/features/health/application/health_connection_controller.dart';
import 'package:cycle_ready/src/features/backup/presentation/backup_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/intervals/presentation/intervals_connection_card.dart';
import 'package:go_router/go_router.dart';
import 'package:cycle_ready/src/features/sync/application/sync_coordinator.dart';
import 'package:cycle_ready/src/features/cloud_sync/presentation/cloud_sync_card.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(healthConnectionControllerProvider);
    final sync = ref.watch(appSyncControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Connections')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bring your data together',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'CycleReady only reads the categories you approve. Imported information is stored locally on this phone.'),
          const SizedBox(height: 20),
          _AutomaticSyncCard(
            sync: sync,
            onSync: () =>
                ref.read(appSyncControllerProvider.notifier).sync(force: true),
          ),
          const SizedBox(height: 12),
          const CloudSyncCard(),
          const SizedBox(height: 12),
          _HealthConnectCard(connection: connection),
          const SizedBox(height: 12),
          const IntervalsConnectionCard(),
          const SizedBox(height: 12),
          const _ConnectionInfoCard(
            icon: Icons.watch_outlined,
            title: 'Garmin workouts and FIT files',
            subtitle:
                'Import completed FIT rides and send planned workouts through Intervals.icu.',
            status: 'Available',
          ),
          const SizedBox(height: 12),
          _ScaleConnectionCard(
            connection: connection,
            onSync: () => ref
                .read(healthConnectionControllerProvider.notifier)
                .syncIfAuthorized(),
            onHistory: () => context.push('/body'),
          ),
          const SizedBox(height: 12),
          const BackupCard(),
        ],
      ),
    );
  }
}

class _AutomaticSyncCard extends StatelessWidget {
  const _AutomaticSyncCard({required this.sync, required this.onSync});

  final AsyncValue<AppSyncState> sync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final value = sync.valueOrNull;
    final lastSuccess = value?.lastSuccess;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          child: value?.syncing == true
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
        ),
        title: const Text('Automatic sync',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${value?.message ?? 'Preparing sync…'}\n'
          '${lastSuccess == null ? 'No successful sync recorded yet' : 'Last successful: ${_syncTime(lastSuccess, context)}'}',
        ),
        trailing: IconButton(
          tooltip: 'Sync everything now',
          onPressed: value?.syncing == true ? null : onSync,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  String _syncTime(DateTime value, BuildContext context) {
    final now = DateTime.now();
    final time = TimeOfDay.fromDateTime(value).format(context);
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return 'today at $time';
    }
    return '${value.day}/${value.month}/${value.year} at $time';
  }
}

class _ScaleConnectionCard extends StatelessWidget {
  const _ScaleConnectionCard({
    required this.connection,
    required this.onSync,
    required this.onHistory,
  });

  final AsyncValue<HealthConnectionState> connection;
  final VoidCallback onSync;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final snapshot = connection.valueOrNull?.lastSnapshot;
    final hasWeight = snapshot?.weightKg != null;
    final weightSources = snapshot?.bodyMeasurements
            .map((value) => value.source)
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .join(', ') ??
        '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RENPHO scales',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Automatic weight import'),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            hasWeight
                ? 'Your scale data is reaching CycleReady through your connected health provider.'
                : 'Weigh in with RENPHO, let it sync to your health provider, then refresh CycleReady.',
          ),
          if (hasWeight) ...[
            const SizedBox(height: 8),
            Text(
              '${snapshot!.weightKg!.toStringAsFixed(1)} kg'
              '${weightSources.isEmpty ? '' : ' · $weightSources'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: connection.isLoading ? null : onSync,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh scale data'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.show_chart),
              label: const Text('View weight history and CSV import'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HealthConnectCard extends ConsumerWidget {
  const _HealthConnectCard({required this.connection});
  final AsyncValue<HealthConnectionState> connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = connection.valueOrNull;
    final authorized = value?.authorized ?? false;
    final snapshot = value?.lastSnapshot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                child: Icon(authorized
                    ? Icons.health_and_safety
                    : Icons.health_and_safety_outlined)),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Health Connect',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Sleep, heart, weight and workouts')
                ])),
            _StatusChip(connected: authorized),
          ]),
          if (value?.message != null) ...[
            const SizedBox(height: 12),
            Text(value!.message!),
          ],
          if (snapshot != null) ...[
            const SizedBox(height: 12),
            Text(
                'Imported: ${snapshot.sleepMinutes ?? 0} sleep minutes · ${snapshot.workoutCount} workouts'),
            if (snapshot.weightKg != null)
              Text(
                  'Latest weight: ${snapshot.weightKg!.toStringAsFixed(1)} kg'),
            if (snapshot.restingHeartRate != null)
              Text(
                'Resting heart rate: ${snapshot.restingHeartRate!.round()} bpm${snapshot.restingHeartRateEstimated ? ' (estimated from overnight samples)' : ''}',
              ),
            if (snapshot.sources.isNotEmpty)
              Text('Sources: ${snapshot.sources.join(', ')}'),
            Text(
              'Last synced: ${TimeOfDay.fromDateTime(snapshot.syncedAt).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (connection.hasError) ...[
            const SizedBox(height: 12),
            Text('Could not connect: ${connection.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: connection.isLoading
                  ? null
                  : () => ref
                      .read(healthConnectionControllerProvider.notifier)
                      .connectAndSync(),
              icon: connection.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(authorized ? 'Sync now' : 'Connect Health Connect'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) => Chip(
        label: Text(connected ? 'Connected' : 'Not connected'),
        avatar: Icon(connected ? Icons.check_circle : Icons.circle_outlined,
            size: 18),
      );
}

class _ConnectionInfoCard extends StatelessWidget {
  const _ConnectionInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Chip(label: Text(status)),
        ),
      );
}
