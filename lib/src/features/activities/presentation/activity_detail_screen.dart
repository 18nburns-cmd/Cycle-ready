import 'dart:math' as math;

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:go_router/go_router.dart';

class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides =
        ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
    final ride = rides.where((ride) => ride.id == id).firstOrNull;
    final settings = ref.watch(athleteSettingsProvider).valueOrNull;
    final sampleState = ref.watch(activityDetailSamplesProvider(id));
    if (ride == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final records = personalBestFlags(
      activityId: id,
      activities: rides.map((ride) => (
            id: ride.id,
            distance: ride.distanceMetres,
            elevation: ride.elevationMetres,
            averagePower: ride.averagePower,
            trainingLoad: ride.trainingLoad,
          )),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride analysis'),
        actions: [
          IconButton(
            tooltip: 'Post-ride debrief',
            onPressed: () => context.push('/activities/$id/debrief'),
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      body: sampleState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StreamError(
          error: error,
          onRetry: () => ref.invalidate(activityDetailSamplesProvider(id)),
        ),
        data: (samples) {
          final streamedPower =
              _sampleAverage(samples.map((sample) => sample.power));
          final streamedHeartRate =
              _sampleAverage(samples.map((sample) => sample.heartRate));
          final averagePower = ride.averagePower ?? streamedPower;
          final averageHeartRate = ride.averageHeartRate ?? streamedHeartRate;
          final normalisedPower = ride.normalisedPower ??
              _normalisedPower(
                samples
                    .where((sample) => sample.power != null)
                    .map((sample) => sample.power!)
                    .toList(),
              );
          final analysis = analyseRide(
            durationSeconds: ride.durationSeconds,
            distanceMetres: ride.distanceMetres,
            ftp: settings?.ftp ?? 200,
            maximumHeartRate: settings?.maximumHeartRate ?? 190,
            weightKg: settings?.weightKg ?? 70,
            averagePower: averagePower,
            averageHeartRate: averageHeartRate,
            normalisedPower: normalisedPower,
            samples: samples.map((sample) => (
                  elapsedSeconds: sample.elapsedSeconds,
                  power: sample.power,
                  heartRate: sample.heartRate,
                )),
          );
          final advanced = calculateAdvancedRideMetrics(
            durationSeconds: ride.durationSeconds,
            samples: samples.map((sample) => (
                  elapsedSeconds: sample.elapsedSeconds,
                  power: sample.power,
                  heartRate: sample.heartRate,
                  cadence: sample.cadence,
                )),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _RideHeader(ride: ride),
              if (records.any) ...[
                const SizedBox(height: 16),
                _Achievements(flags: records),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Ride summary'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.75,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _Stat('Distance', Units.distance(ride.distanceMetres),
                      Icons.route_outlined),
                  _Stat('Duration', _duration(ride.durationSeconds),
                      Icons.timer_outlined),
                  _Stat(
                      'Average speed',
                      '${analysis.averageSpeedMph.toStringAsFixed(1)} mph',
                      Icons.speed),
                  _Stat('Elevation', Units.elevation(ride.elevationMetres),
                      Icons.landscape_outlined),
                  _Stat('Training load', ride.trainingLoad?.toString() ?? '—',
                      Icons.monitor_heart_outlined),
                  _Stat(
                      'Intensity',
                      analysis.intensityFactor?.toStringAsFixed(2) ?? '—',
                      Icons.bolt_outlined),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Power and heart rate'),
              _PerformanceCard(
                analysis: analysis,
                averagePower: averagePower,
                averageHeartRate: averageHeartRate,
                normalisedPower: normalisedPower,
              ),
              if (samples.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Training insights'),
                _TrainingInsightsCard(
                  metrics: advanced,
                  variabilityIndex: analysis.variabilityIndex,
                ),
                if (advanced.bestEfforts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Best power efforts'),
                  _BestEffortsCard(efforts: advanced.bestEfforts),
                ],
              ],
              if (samples.any((sample) =>
                  sample.latitude != null && sample.longitude != null)) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Ride map'),
                _RideMap(samples: samples),
              ],
              if (samples.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Ride timeline'),
                _TimelineChart(samples: samples),
                if (analysis.powerZones.any((zone) => zone.seconds > 0)) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Power zones'),
                  _ZoneCard(zones: analysis.powerZones),
                ],
                if (analysis.heartRateZones
                    .any((zone) => zone.seconds > 0)) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Heart-rate zones'),
                  _ZoneCard(zones: analysis.heartRateZones),
                ],
              ] else ...[
                const SizedBox(height: 16),
                const _DataNotice(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RideHeader extends StatelessWidget {
  const _RideHeader({required this.ride});
  final Activity ride;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.directions_bike, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${_date(ride.startedAt)} · ${_source(ride.source)}'),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.flags});
  final PersonalBestFlags flags;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (flags.longestDistance) 'Longest ride',
      if (flags.highestElevation) 'Most elevation',
      if (flags.highestAveragePower) 'Highest average power',
      if (flags.highestTrainingLoad) 'Highest training load',
    ];
    return Card(
      color: const Color(0xFF3A2D0B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.emoji_events, color: Color(0xFFFFD166)),
            SizedBox(width: 8),
            Text('Personal best',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels
                .map((label) => Chip(
                      avatar: const Icon(Icons.star, size: 16),
                      label: Text(label),
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.analysis,
    required this.averagePower,
    required this.averageHeartRate,
    required this.normalisedPower,
  });
  final RideAnalysis analysis;
  final int? averagePower;
  final int? averageHeartRate;
  final int? normalisedPower;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 20,
            children: [
              _PerformanceValue(
                  value: averagePower == null ? '—' : '$averagePower W',
                  label: 'AVG POWER'),
              _PerformanceValue(
                  value: normalisedPower == null ? '—' : '$normalisedPower W',
                  label: 'NORMALISED'),
              _PerformanceValue(
                  value:
                      averageHeartRate == null ? '—' : '$averageHeartRate bpm',
                  label: 'AVG HR'),
              _PerformanceValue(
                  value:
                      analysis.powerHeartRateRatio?.toStringAsFixed(2) ?? '—',
                  label: 'W / BPM'),
              _PerformanceValue(
                  value: analysis.variabilityIndex?.toStringAsFixed(2) ?? '—',
                  label: 'VARIABILITY'),
              _PerformanceValue(
                  value: analysis.workKilojoules == null
                      ? '—'
                      : '${analysis.workKilojoules!.round()} kJ',
                  label: 'WORK'),
              _PerformanceValue(
                  value: analysis.powerToWeight?.toStringAsFixed(2) ?? '—',
                  label: 'W / KG'),
            ],
          ),
        ),
      );
}

class _PerformanceValue extends StatelessWidget {
  const _PerformanceValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 105,
        child: Column(children: [
          Text(value,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: .8)),
        ]),
      );
}

class _TrainingInsightsCard extends StatelessWidget {
  const _TrainingInsightsCard({
    required this.metrics,
    required this.variabilityIndex,
  });
  final AdvancedRideMetrics metrics;
  final double? variabilityIndex;

  @override
  Widget build(BuildContext context) {
    final drift = metrics.aerobicDecouplingPercent;
    final pacing = variabilityIndex == null
        ? 'Pacing insight needs average and normalised power.'
        : variabilityIndex! <= 1.05
            ? 'Power delivery was very steady.'
            : variabilityIndex! <= 1.12
                ? 'Power varied moderately with terrain or changes in effort.'
                : 'Power was highly variable, typical of intervals, racing or rolling terrain.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _InsightValue(
                    label: 'AEROBIC DRIFT',
                    value: drift == null
                        ? '—'
                        : '${drift >= 0 ? '+' : ''}${drift.toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _InsightValue(
                    label: 'AVG CADENCE',
                    value: metrics.averageCadence == null
                        ? '—'
                        : '${metrics.averageCadence} rpm',
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(metrics.decouplingSummary),
            const SizedBox(height: 8),
            Text(pacing),
            const SizedBox(height: 14),
            Text(
              'Stream coverage: ${metrics.powerCoveragePercent}% power · '
              '${metrics.heartRateCoveragePercent}% heart rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightValue extends StatelessWidget {
  const _InsightValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: .8),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      );
}

class _BestEffortsCard extends StatelessWidget {
  const _BestEffortsCard({required this.efforts});
  final List<BestPowerEffort> efforts;

  @override
  Widget build(BuildContext context) {
    final maximum = efforts.map((effort) => effort.watts).reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: efforts.map((effort) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      effort.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: effort.watts / maximum,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF19E56F),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${effort.watts} W',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RideMap extends StatelessWidget {
  const _RideMap({required this.samples});
  final List<ActivitySample> samples;

  @override
  Widget build(BuildContext context) {
    final points = samples
        .where((sample) =>
            sample.latitude != null &&
            sample.longitude != null &&
            sample.latitude!.abs() <= 90 &&
            sample.longitude!.abs() <= 180)
        .map((sample) => LatLng(sample.latitude!, sample.longitude!))
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(28),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cycleready.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4,
                      color: const Color(0xFF19E56F),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.samples});
  final List<ActivitySample> samples;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          child: Column(children: [
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _TimelinePainter(samples),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(spacing: 18, children: [
              _Legend(color: Color(0xFF19E56F), label: 'Power'),
              _Legend(color: Color(0xFFFF6B6B), label: 'Heart rate'),
            ]),
          ]),
        ),
      );
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.samples);
  final List<ActivitySample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .10)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxSeconds = math.max(
        1, samples.map((sample) => sample.elapsedSeconds).reduce(math.max));
    void draw(
      int? Function(ActivitySample) selector,
      Color color,
      double fallbackMax,
    ) {
      final available =
          samples.where((sample) => selector(sample) != null).toList();
      if (available.length < 2) return;
      final maxValue = math.max(
          fallbackMax,
          available
              .map((sample) => selector(sample)!.toDouble())
              .reduce(math.max));
      final path = Path();
      for (var i = 0; i < available.length; i++) {
        final sample = available[i];
        final x = sample.elapsedSeconds / maxSeconds * size.width;
        final y = size.height - selector(sample)! / maxValue * size.height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    draw((sample) => sample.power, const Color(0xFF19E56F), 300);
    draw((sample) => sample.heartRate, const Color(0xFFFF6B6B), 200);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.samples != samples;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 4, color: color),
        const SizedBox(width: 5),
        Text(label),
      ]);
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zones});
  final List<ZoneDuration> zones;

  @override
  Widget build(BuildContext context) {
    final total = zones.fold<int>(0, (sum, zone) => sum + zone.seconds);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: zones.map((zone) {
            final fraction = total == 0 ? 0.0 : zone.seconds / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 28,
                    child: Text(zone.name,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(9),
                    color: Color(zone.colorValue),
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 54,
                  child: Text(_shortDuration(zone.seconds),
                      textAlign: TextAlign.end),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DataNotice extends StatelessWidget {
  const _DataNotice();

  @override
  Widget build(BuildContext context) => const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Detailed streams unavailable'),
          subtitle: Text(
            'No power, heart-rate or route stream was supplied for this ride. '
            'You can still import the original FIT file.',
          ),
        ),
      );
}

class _StreamError extends StatelessWidget {
  const _StreamError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Could not download detailed ride data',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                error.toString().replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
String _shortDuration(int seconds) =>
    seconds >= 3600 ? _duration(seconds) : '${seconds ~/ 60}m';
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

int? _sampleAverage(Iterable<int?> values) {
  final recorded = values.whereType<int>().where((value) => value > 0).toList();
  if (recorded.isEmpty) return null;
  return (recorded.fold<int>(0, (sum, value) => sum + value) / recorded.length)
      .round();
}

/// Provides a local fallback when Intervals.icu supplies power samples but its
/// summary value is absent. Streams are normally one sample per second.
int? _normalisedPower(List<int> power) {
  if (power.length < 30) return null;
  var rollingSum = power.take(30).fold<int>(0, (sum, value) => sum + value);
  var fourthPowerTotal = math.pow(rollingSum / 30, 4).toDouble();
  var windows = 1;
  for (var index = 30; index < power.length; index++) {
    rollingSum += power[index] - power[index - 30];
    fourthPowerTotal += math.pow(rollingSum / 30, 4);
    windows++;
  }
  return math.pow(fourthPowerTotal / windows, .25).round();
}

String _source(String source) => switch (source) {
      'intervalsIcu' => 'Intervals.icu',
      'healthConnect' => 'Health Connect',
      'fitFile' => 'FIT file',
      _ => source,
    };
