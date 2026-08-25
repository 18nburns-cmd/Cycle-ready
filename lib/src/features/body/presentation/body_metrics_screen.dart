import 'dart:math' as math;

import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/body/application/body_measurement_controller.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:cycle_ready/src/features/health/application/health_connection_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BodyMetricsScreen extends ConsumerWidget {
  const BodyMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements =
        ref.watch(bodyMeasurementsProvider).valueOrNull ?? const [];
    final settings = ref.watch(athleteSettingsProvider).valueOrNull;
    final latest = measurements.lastOrNull;
    final trend = _trend(measurements);
    final powerToWeight = latest == null || settings == null
        ? null
        : settings.ftp / latest.weightKg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body & weight',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Refresh RENPHO weight',
            onPressed: () => ref
                .read(healthConnectionControllerProvider.notifier)
                .syncIfAuthorized(),
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Import AFit CSV',
            onPressed: () => _importCsv(context, ref),
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMeasurement(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add weight'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.monitor_weight_outlined, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'RENPHO automatic import',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Weigh in with RENPHO, allow it to update your connected health provider, then refresh. CycleReady also refreshes automatically when opened.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(healthConnectionControllerProvider.notifier)
                          .syncIfAuthorized(),
                      icon: const Icon(Icons.sync),
                      label: const Text('Refresh scale data'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (latest == null)
            const _EmptyCard()
          else ...[
            Row(children: [
              Expanded(
                child: _MetricCard(
                  label: 'LATEST WEIGHT',
                  value: '${latest.weightKg.toStringAsFixed(1)} kg',
                  detail: _date(latest.measuredAt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'POWER / WEIGHT',
                  value: powerToWeight == null
                      ? '—'
                      : '${powerToWeight.toStringAsFixed(2)} W/kg',
                  detail: settings == null
                      ? 'Set your FTP'
                      : '${settings.ftp} W FTP',
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _MetricCard(
              label: '7-DAY TREND',
              value: trend == null
                  ? 'Not enough data'
                  : '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)} kg',
              detail: 'Seven-day average compared with the prior seven days',
            ),
            const SizedBox(height: 22),
            Text('Weight trend',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Card(
              child: SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: CustomPaint(
                    painter: _WeightChartPainter(
                      measurements.length > 60
                          ? measurements.sublist(measurements.length - 60)
                          : measurements,
                      Theme.of(context).colorScheme,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recent measurements',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: measurements.reversed.take(12).map((value) {
                  return ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text('${value.weightKg.toStringAsFixed(1)} kg'),
                    subtitle: Text(
                      '${_date(value.measuredAt)} · ${_source(value.source)}',
                    ),
                    trailing: value.bodyFatPercent == null
                        ? null
                        : Text(
                            '${value.bodyFatPercent!.toStringAsFixed(1)}% fat'),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Daily weight and body-fat estimates fluctuate with hydration. Use the multi-week trend rather than a single reading.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final count = await ref.read(bodyMeasurementControllerProvider).importCsv();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0
          ? 'No compatible measurements found.'
          : 'Imported $count measurements.'),
    ));
  }

  Future<void> _addMeasurement(BuildContext context, WidgetRef ref) async {
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add measurement'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: weight,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
            ),
          ),
          TextField(
            controller: bodyFat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Body fat (optional)',
              suffixText: '%',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                // Keep the focused TextField and its inherited dependencies
                // alive until the keyboard has detached from this route.
                FocusScope.of(context).unfocus();
                await Future<void>.delayed(
                  const Duration(milliseconds: 250),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Save')),
        ],
      ),
    );
    final weightValue = double.tryParse(weight.text);
    final fatValue = double.tryParse(bodyFat.text);
    if (saved == true) {
      if (weightValue == null || weightValue < 30 || weightValue > 250) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter a valid weight between 30 and 250 kg.'),
            ),
          );
        }
      } else {
        // Wait until the dialog route has completed the frame that removes its
        // TextFields before the database stream rebuilds this screen.
        await WidgetsBinding.instance.endOfFrame;
        try {
          await ref.read(bodyMeasurementControllerProvider).saveManual(
                weightKg: weightValue,
                bodyFatPercent: fatValue,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Weight saved.')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('That weight could not be saved. Try again.'),
              ),
            );
          }
        }
      }
    }
    // showDialog completes before its reverse transition necessarily disposes
    // every TextField, so controllers must outlive that animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    weight.dispose();
    bodyFat.dispose();
  }

  static double? _trend(List<BodyMetric> values) {
    if (values.length < 2) return null;
    final now = values.last.measuredAt;
    final current = values
        .where((value) =>
            value.measuredAt.isAfter(now.subtract(const Duration(days: 7))))
        .toList();
    final prior = values
        .where((value) =>
            value.measuredAt.isAfter(now.subtract(const Duration(days: 14))) &&
            !value.measuredAt.isAfter(now.subtract(const Duration(days: 7))))
        .toList();
    if (current.isEmpty || prior.isEmpty) return null;
    double average(List<BodyMetric> list) =>
        list.fold<double>(0, (sum, value) => sum + value.weightKg) /
        list.length;
    return average(current) - average(prior);
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  static String _source(String value) {
    if (value.startsWith('healthConnect:')) {
      return value.substring('healthConnect:'.length);
    }
    if (value.startsWith('bluetooth:')) {
      return '${value.substring('bluetooth:'.length)} Bluetooth';
    }
    return value == 'csv' ? 'CSV import' : 'Manual';
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => Card(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.monitor_weight_outlined, size: 42),
            SizedBox(height: 12),
            Text('No weight history yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              'Sync your RENPHO measurement through your health provider, add a measurement, or import a CSV file.',
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter(this.values, this.colors);
  final List<BodyMetric> values;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final weights = values.map((value) => value.weightKg);
    final low = weights.reduce(math.min) - .5;
    final high = weights.reduce(math.max) + .5;
    final span = math.max(1.0, high - low);
    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (var row = 0; row <= 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          size.height - (values[index].weightKg - low) / span * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
