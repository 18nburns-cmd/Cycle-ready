import 'dart:math' as math;

import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';
import 'package:cycle_ready/src/features/activities/domain/critical_power.dart';
import 'package:cycle_ready/src/features/activities/domain/power_curve_progress.dart';
import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/activities/domain/training_response.dart';
import 'package:cycle_ready/src/features/body/application/body_measurement_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final curve = ref.watch(powerCurveProvider);
    final criticalPower = ref.watch(criticalPowerProvider);
    final progress =
        ref.watch(powerCurveProgressProvider).valueOrNull ?? const [];
    final training = ref.watch(fitnessMetricsProvider);
    final response = assessTrainingResponse(
      training: training,
      momentum: assessPerformanceMomentum(progress),
    );
    final settings = ref.watch(athleteSettingsProvider).valueOrNull;
    final measurements =
        ref.watch(bodyMeasurementsProvider).valueOrNull ?? const [];
    final ftp = settings?.ftp ?? 200;
    final weight = measurements.lastOrNull?.weightKg ?? settings?.weightKg;
    final wattsPerKg = weight == null || weight <= 0 ? null : ftp / weight;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Performance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Calculate FTP',
            onPressed: () => context.push('/ftp-estimate'),
            icon: const Icon(Icons.calculate_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(powerRideInputsProvider);
          await ref.read(powerCurveProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [
            Row(
              children: [
                Expanded(
                  child: _PerformanceMetric(
                    label: 'CURRENT FTP',
                    value: '$ftp W',
                    icon: Icons.bolt,
                    onTap: () => context.push('/ftp-estimate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PerformanceMetric(
                    label: 'POWER / WEIGHT',
                    value: wattsPerKg == null
                        ? '—'
                        : '${wattsPerKg.toStringAsFixed(2)} W/kg',
                    icon: Icons.monitor_weight_outlined,
                    onTap: () => context.push('/body'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _PerformanceMetric(
                  label: 'CRITICAL POWER',
                  value:
                      criticalPower == null ? '—' : '${criticalPower.watts} W',
                  icon: Icons.speed,
                  onTap: () => _showCriticalPowerInfo(context, criticalPower),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PerformanceMetric(
                  label: 'W′ CAPACITY',
                  value: criticalPower == null
                      ? '—'
                      : '${criticalPower.wPrimeKilojoules.toStringAsFixed(1)} kJ',
                  icon: Icons.battery_charging_full,
                  onTap: () => _showCriticalPowerInfo(context, criticalPower),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _TrainingResponseCard(response: response),
            const SizedBox(height: 10),
            Text(
              'Eight-week power curve',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Tap any point to see the power, duration and ride that produced it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            if (curve.valueOrNull case final points?)
              points.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No detailed power samples are available yet. Sync '
                          'Intervals.icu or import a FIT ride with power data.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Stack(children: [
                      _PowerCurveCard(
                        points: points,
                        ftp: ftp,
                        selectedIndex:
                            (selectedIndex ?? points.length - 1).clamp(
                          0,
                          points.length - 1,
                        ),
                        onSelected: (value) =>
                            setState(() => selectedIndex = value),
                        onOpenRide: (id) => context.push('/activities/$id'),
                        progress: progress,
                      ),
                      if (curve.isRefreshing)
                        const Positioned(
                          left: 12,
                          right: 12,
                          top: 0,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ])
            else
              curve.when(
                loading: () => const Card(
                  child: SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Power curve unavailable: $error'),
                  ),
                ),
                data: (_) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  void _showCriticalPowerInfo(
      BuildContext context, CriticalPowerEstimate? estimate) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Critical Power and W′',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(estimate == null
              ? 'CycleReady needs at least three strong efforts between 3 and 30 minutes, spanning at least 10 minutes, before it will show a model.'
              : 'Your rolling eight-week model estimates ${estimate.watts} W Critical Power and ${estimate.wPrimeKilojoules.toStringAsFixed(1)} kJ W′. Confidence is ${estimate.confidence.name}; the mathematical fit is ${(estimate.fit * 100).toStringAsFixed(1)}%.'),
          const SizedBox(height: 10),
          const Text(
              'Critical Power estimates sustainable aerobic power. W′ estimates the finite work you can perform above it. FTP remains in the app for familiar training zones.'),
        ]),
      ),
    );
  }
}

class _TrainingResponseCard extends StatelessWidget {
  const _TrainingResponseCard({required this.response});

  final TrainingResponse response;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (response.status) {
      TrainingResponseStatus.productive => (
          Icons.trending_up,
          const Color(0xFF19E56F)
        ),
      TrainingResponseStatus.maintaining => (
          Icons.balance,
          const Color(0xFF4FA9FF)
        ),
      TrainingResponseStatus.fatigued => (
          Icons.battery_alert_outlined,
          const Color(0xFFFFB020)
        ),
      TrainingResponseStatus.rebuilding => (
          Icons.construction,
          const Color(0xFFB58CFF)
        ),
      TrainingResponseStatus.insufficientData => (
          Icons.hourglass_top,
          Theme.of(context).colorScheme.outline
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRAINING RESPONSE',
                    style: Theme.of(context).textTheme.labelSmall),
                Text(response.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(response.explanation,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
}

class _PowerCurveCard extends StatelessWidget {
  const _PowerCurveCard({
    required this.points,
    required this.ftp,
    required this.selectedIndex,
    required this.onSelected,
    required this.onOpenRide,
    required this.progress,
  });

  final List<PowerCurvePoint> points;
  final int ftp;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<String> onOpenRide;
  final List<PowerCurveProgress> progress;

  @override
  Widget build(BuildContext context) {
    final selected = points[selectedIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpenRide(selected.activityId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CurveValue(
                      value: powerDurationLabel(selected.seconds),
                      label: 'DURATION',
                    ),
                    _CurveValue(
                      value: '${selected.watts} W',
                      label: 'BEST POWER',
                    ),
                    _CurveValue(
                      value:
                          '${selected.achievedAt.day}/${selected.achievedAt.month}',
                      label: 'RIDE',
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    const left = 42.0;
                    final width = constraints.maxWidth - left - 10;
                    final ratio = ((details.localPosition.dx - left) / width)
                        .clamp(0.0, 1.0);
                    onSelected((ratio * (points.length - 1)).round());
                  },
                  child: CustomPaint(
                    painter: _PowerCurvePainter(
                      points: points,
                      selectedIndex: selectedIndex,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const Divider(height: 16),
            _PowerProgressSummary(progress: progress),
            if (progress.isNotEmpty) const Divider(height: 16),
            _PowerProfileInsights(points: points, ftp: ftp),
          ],
        ),
      ),
    );
  }
}

class _PowerProgressSummary extends StatelessWidget {
  const _PowerProgressSummary({required this.progress});

  final List<PowerCurveProgress> progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return Text(
        'Four-week progress will appear once both four-week periods contain comparable power efforts.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final momentum = assessPerformanceMomentum(progress)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Four-week progress',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var index = 0; index < progress.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              Expanded(child: _ProgressValue(value: progress[index])),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Best power from the latest 28 days compared with the preceding 28 days.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 9),
        _MomentumInsight(momentum: momentum),
      ],
    );
  }
}

class _MomentumInsight extends StatelessWidget {
  const _MomentumInsight({required this.momentum});

  final PerformanceMomentum momentum;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (momentum.status) {
      PerformanceMomentumStatus.improving => (
          Icons.trending_up,
          const Color(0xFF19E56F)
        ),
      PerformanceMomentumStatus.stable => (
          Icons.trending_flat,
          const Color(0xFF4FA9FF)
        ),
      PerformanceMomentumStatus.mixed => (
          Icons.swap_vert,
          const Color(0xFFFFB020)
        ),
      PerformanceMomentumStatus.declining => (
          Icons.trending_down,
          Theme.of(context).colorScheme.error
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(momentum.headline,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(momentum.explanation,
                  style: Theme.of(context).textTheme.bodySmall),
              if (momentum.comparisonCount < 3) ...[
                const SizedBox(height: 4),
                Text(
                  'Early signal: only ${momentum.comparisonCount} comparable duration is available.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _ProgressValue extends StatelessWidget {
  const _ProgressValue({required this.value});

  final PowerCurveProgress value;

  @override
  Widget build(BuildContext context) {
    final change = value.changePercent;
    final color = change > 1
        ? const Color(0xFF19E56F)
        : change < -1
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFFFB020);
    final sign = change > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(powerDurationLabel(value.seconds),
            style: Theme.of(context).textTheme.labelSmall),
        Text('$sign${change.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        Text('${value.currentWatts} W',
            style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }
}

class _PowerProfileInsights extends StatelessWidget {
  const _PowerProfileInsights({required this.points, required this.ftp});

  final List<PowerCurvePoint> points;
  final int ftp;

  @override
  Widget build(BuildContext context) {
    const areas = [
      (name: 'Sprint', seconds: 5, target: 4.5, detail: 'accelerations'),
      (name: 'Anaerobic', seconds: 60, target: 1.8, detail: 'short attacks'),
      (name: 'VO₂ max', seconds: 300, target: 1.15, detail: 'short climbs'),
      (name: 'Threshold', seconds: 1200, target: .95, detail: 'hard efforts'),
      (name: 'Endurance', seconds: 3600, target: .80, detail: 'steady power'),
    ];
    final scored = [
      for (final area in areas)
        if (points.any((point) => point.seconds == area.seconds))
          (
            area: area,
            point: points.firstWhere(
              (point) => point.seconds == area.seconds,
            ),
            score: points
                    .firstWhere((point) => point.seconds == area.seconds)
                    .watts /
                ftp /
                area.target,
          ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    if (scored.length < 2) {
      return const Text(
        'Complete more rides with detailed power data to identify strengths '
        'and development areas.',
        textAlign: TextAlign.center,
      );
    }
    final strongest = scored.first;
    final attention = scored.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Power profile',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _ProfileArea(
          icon: Icons.check_circle,
          color: const Color(0xFF19E56F),
          title: 'Strong area: ${strongest.area.name}',
          detail: '${strongest.point.watts} W for '
              '${powerDurationLabel(strongest.point.seconds)} · '
              'good ${strongest.area.detail}.',
        ),
        const SizedBox(height: 5),
        _ProfileArea(
          icon: Icons.tips_and_updates_outlined,
          color: const Color(0xFFFFB020),
          title: 'Needs attention: ${attention.area.name}',
          detail: '${attention.point.watts} W for '
              '${powerDurationLabel(attention.point.seconds)} · '
              'develop ${attention.area.detail}.',
        ),
        const SizedBox(height: 5),
        Text(
          'Compared with a balanced profile relative to your $ftp W FTP. '
          'This describes the balance of your own curve, not your ranking '
          'against other riders.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ProfileArea extends StatelessWidget {
  const _ProfileArea({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CurveValue extends StatelessWidget {
  const _CurveValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _PowerCurvePainter extends CustomPainter {
  const _PowerCurvePainter({
    required this.points,
    required this.selectedIndex,
    required this.color,
  });

  final List<PowerCurvePoint> points;
  final int selectedIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 12.0;
    const bottom = 28.0;
    final width = size.width - left - 10;
    final height = size.height - top - bottom;
    final maximum = points.map((point) => point.watts).reduce(math.max);
    final minimum = points.map((point) => point.watts).reduce(math.min);
    final span = math.max(50, maximum - minimum);
    final grid = Paint()..color = Colors.grey.withValues(alpha: .22);
    for (var row = 0; row <= 4; row++) {
      final y = top + height * row / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      _paintText(
        canvas,
        '${(maximum - span * row / 4).round()}',
        Offset(0, y - 7),
      );
    }
    double x(int index) =>
        left + (points.length == 1 ? .5 : index / (points.length - 1)) * width;
    double y(int watts) => top + (maximum - watts) / span * height;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = Offset(x(index), y(points[index].watts));
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var index = 0; index < points.length; index++) {
      final point = Offset(x(index), y(points[index].watts));
      canvas.drawCircle(
        point,
        index == selectedIndex ? 6 : 3,
        Paint()..color = index == selectedIndex ? Colors.white : color,
      );
      if (index.isEven || index == points.length - 1) {
        _paintText(
          canvas,
          powerDurationLabel(points[index].seconds),
          Offset(point.dx - 10, top + height + 8),
        );
      }
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PowerCurvePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.color != color;
}
