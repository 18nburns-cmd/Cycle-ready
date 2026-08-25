import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_portal_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebRideDetailDialog extends ConsumerWidget {
  const WebRideDetailDialog({required this.activity, super.key});

  final WebActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(cloudActivitySamplesProvider(activity.id));
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(activity.title),
        ),
        body: samples.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Detailed ride samples could not be loaded: $error'),
            ),
          ),
          data: (values) => _RideSampleAnalysis(
            activity: activity,
            samples: values,
          ),
        ),
      ),
    );
  }
}

class _RideSampleAnalysis extends StatelessWidget {
  const _RideSampleAnalysis({required this.activity, required this.samples});

  final WebActivity activity;
  final List<CloudActivitySample> samples;

  @override
  Widget build(BuildContext context) {
    final route = samples
        .where((sample) => sample.latitude != null && sample.longitude != null)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric('Distance',
                      '${(activity.distanceMetres / 1609.344).toStringAsFixed(1)} mi'),
                  _Metric('Duration',
                      '${(activity.durationSeconds / 3600).toStringAsFixed(2)} h'),
                  _Metric('Elevation',
                      '${(activity.elevationMetres * 3.28084).toStringAsFixed(0)} ft'),
                  _Metric('Average power', _value(activity.averagePower, ' W')),
                  _Metric('Normalised power',
                      _value(activity.normalisedPower, ' W')),
                  _Metric(
                      'Average HR', _value(activity.averageHeartRate, ' bpm')),
                  _Metric('Cadence', _value(activity.averageCadence, ' rpm')),
                  _Metric('Training load',
                      activity.trainingLoad.toStringAsFixed(0)),
                ],
              ),
              const SizedBox(height: 20),
              if (samples.isEmpty)
                const _Panel(
                  title: 'Detailed samples not uploaded yet',
                  child: Text(
                    'Install the latest Android build and run CycleReady cloud upload to make this ride’s power, heart-rate, cadence and route streams available.',
                  ),
                )
              else ...[
                _Panel(
                  title: 'Power',
                  child: _SampleChart(
                    samples: samples,
                    selector: (sample) => sample.power?.toDouble(),
                    colour: Colors.blueAccent,
                    unit: 'W',
                  ),
                ),
                _Panel(
                  title: 'Heart rate',
                  child: _SampleChart(
                    samples: samples,
                    selector: (sample) => sample.heartRate?.toDouble(),
                    colour: Colors.redAccent,
                    unit: 'bpm',
                  ),
                ),
                _Panel(
                  title: 'Cadence',
                  child: _SampleChart(
                    samples: samples,
                    selector: (sample) => sample.cadence?.toDouble(),
                    colour: Colors.tealAccent,
                    unit: 'rpm',
                  ),
                ),
                _Panel(
                  title: 'Elevation',
                  child: _SampleChart(
                    samples: samples,
                    selector: (sample) => sample.altitudeMetres == null
                        ? null
                        : sample.altitudeMetres! * 3.28084,
                    colour: Colors.orangeAccent,
                    unit: 'ft',
                  ),
                ),
                if (route.isNotEmpty)
                  _Panel(title: 'Route', child: _RoutePlot(samples: route)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          width: 145,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 5),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _SampleChart extends StatelessWidget {
  const _SampleChart({
    required this.samples,
    required this.selector,
    required this.colour,
    required this.unit,
  });

  final List<CloudActivitySample> samples;
  final double? Function(CloudActivitySample sample) selector;
  final Color colour;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final points = samples
        .map((sample) => (sample.elapsedSeconds.toDouble(), selector(sample)))
        .where((point) => point.$2 != null)
        .map((point) => Offset(point.$1, point.$2!))
        .toList();
    if (points.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No recorded data for this stream.')),
      );
    }
    final peak = points.fold<double>(
        0, (value, point) => point.dy > value ? point.dy : value);
    final average =
        points.fold<double>(0, (sum, point) => sum + point.dy) / points.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Average ${average.toStringAsFixed(0)} $unit • Peak ${peak.toStringAsFixed(0)} $unit'),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(points: points, colour: colour),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.points, required this.colour});
  final List<Offset> points;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final minX = points.first.dx;
    final maxX = points.last.dx == minX ? minX + 1 : points.last.dx;
    final minY = points.fold<double>(
        points.first.dy, (value, point) => point.dy < value ? point.dy : value);
    final rawMaxY = points.fold<double>(
        points.first.dy, (value, point) => point.dy > value ? point.dy : value);
    final maxY = rawMaxY == minY ? minY + 1 : rawMaxY;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = (point.dx - minX) / (maxX - minX) * size.width;
      final y = size.height - (point.dy - minY) / (maxY - minY) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.colour != colour;
}

class _RoutePlot extends StatelessWidget {
  const _RoutePlot({required this.samples});
  final List<CloudActivitySample> samples;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 300,
        width: double.infinity,
        child: CustomPaint(painter: _RoutePainter(samples)),
      );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.samples);
  final List<CloudActivitySample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final latitudes = samples.map((sample) => sample.latitude!).toList();
    final longitudes = samples.map((sample) => sample.longitude!).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final rawMaxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLon = longitudes.reduce((a, b) => a < b ? a : b);
    final rawMaxLon = longitudes.reduce((a, b) => a > b ? a : b);
    final maxLat = rawMaxLat == minLat ? minLat + .0001 : rawMaxLat;
    final maxLon = rawMaxLon == minLon ? minLon + .0001 : rawMaxLon;
    final path = Path();
    for (var index = 0; index < samples.length; index++) {
      final x =
          (samples[index].longitude! - minLon) / (maxLon - minLon) * size.width;
      final y = size.height -
          (samples[index].latitude! - minLat) / (maxLat - minLat) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawRect(Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: .04));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.tealAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.samples != samples;
}

String _value(Object? value, String suffix) =>
    value == null ? 'Not available' : '$value$suffix';
