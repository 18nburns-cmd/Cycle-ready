import 'package:cycle_ready/src/core/database/app_database.dart' as db;
import 'package:cycle_ready/src/features/activities/application/ftp_estimate_controller.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/ftp_estimator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FtpEstimateScreen extends ConsumerWidget {
  const FtpEstimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculation = ref.watch(ftpEstimateControllerProvider);
    final history =
        ref.watch(ftpEstimateHistoryProvider).valueOrNull ?? const [];
    final settings = ref.watch(athleteSettingsProvider).valueOrNull;
    final current = calculation.valueOrNull;
    final stored = history.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculated FTP',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _CurrentFtp(value: settings?.ftp ?? 200),
          const SizedBox(height: 16),
          if (calculation.isLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analysing eight weeks of power data…'),
                ]),
              ),
            )
          else if (current != null)
            _EstimateCard(
              watts: current.watts,
              lowWatts: current.lowWatts,
              highWatts: current.highWatts,
              confidence: current.confidence.name,
              rides: current.rideCount,
              coverage: current.durationCoverage,
              accepted: stored?.accepted ?? false,
              onAccept: () => _accept(context, ref),
            )
          else if (stored != null)
            _EstimateCard(
              watts: stored.watts,
              lowWatts: stored.lowWatts,
              highWatts: stored.highWatts,
              confidence: stored.confidence,
              rides: stored.rideCount,
              coverage: stored.durationCoverage,
              accepted: stored.accepted,
              onAccept: () => _accept(context, ref),
            )
          else
            const _EmptyEstimate(),
          if (calculation.hasError) ...[
            const SizedBox(height: 12),
            Text('Could not calculate FTP: ${calculation.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: calculation.isLoading
                ? null
                : () => ref
                    .read(ftpEstimateControllerProvider.notifier)
                    .calculate(),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(stored == null ? 'Calculate FTP' : 'Recalculate FTP'),
          ),
          if (current != null && current.efforts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Power-duration evidence'),
            _EffortCard(efforts: current.efforts),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('How it works'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'CycleReady analyses the best sustained powers between 3 and 60 minutes from detailed FIT or Intervals.icu data in the previous eight weeks. Longer efforts receive more weight, while a critical-power model checks the shorter efforts. Unusual outliers are excluded before the final range is calculated.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Estimate history'),
            ...history.take(8).map(_HistoryTile.new),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    await ref.read(ftpEstimateControllerProvider.notifier).acceptLatest();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('FTP updated. Training zones and load recalculated.')),
    );
  }
}

class _CurrentFtp extends StatelessWidget {
  const _CurrentFtp({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.bolt),
          ),
          title: const Text('Current configured FTP'),
          trailing: Text('$value W',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      );
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.watts,
    required this.lowWatts,
    required this.highWatts,
    required this.confidence,
    required this.rides,
    required this.coverage,
    required this.accepted,
    required this.onAccept,
  });
  final int watts;
  final int lowWatts;
  final int highWatts;
  final String confidence;
  final int rides;
  final int coverage;
  final bool accepted;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text('ESTIMATED FTP',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 8),
            Text('$watts W',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: const Color(0xFF19E56F),
                    fontWeight: FontWeight.w700)),
            Text('Likely range $lowWatts–$highWatts W'),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _MiniMetric(value: confidence.toUpperCase(), label: 'CONFIDENCE'),
              _MiniMetric(value: '$rides', label: 'RIDES'),
              _MiniMetric(value: '$coverage/8', label: 'DURATIONS'),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: accepted
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check),
                      label: const Text('Accepted as current FTP'),
                    )
                  : FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept new FTP'),
                    ),
            ),
          ]),
        ),
      );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: .7)),
      ]);
}

class _EmptyEstimate extends StatelessWidget {
  const _EmptyEstimate();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.query_stats, size: 42),
            SizedBox(height: 12),
            Text('No calculated FTP yet',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              'Calculate from detailed FIT or Intervals.icu power data recorded during the last eight weeks.',
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

class _EffortCard extends StatelessWidget {
  const _EffortCard({required this.efforts});
  final Map<int, double> efforts;

  @override
  Widget build(BuildContext context) {
    final maximum = efforts.values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: ftpDurations.where(efforts.containsKey).map((duration) {
            final power = efforts[duration]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 42, child: Text(_durationLabel(duration))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: power / maximum,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  child: Text('${power.round()} W', textAlign: TextAlign.end),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.estimate);
  final db.FtpEstimate estimate;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(estimate.accepted ? Icons.check_circle : Icons.history),
          title: Text('${estimate.watts} W'),
          subtitle: Text(
              '${estimate.estimatedAt.day}/${estimate.estimatedAt.month}/${estimate.estimatedAt.year} · ${estimate.confidence} confidence'),
          trailing: Text('${estimate.lowWatts}–${estimate.highWatts} W'),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

String _durationLabel(int seconds) =>
    seconds < 3600 ? '${seconds ~/ 60}m' : '60m';
