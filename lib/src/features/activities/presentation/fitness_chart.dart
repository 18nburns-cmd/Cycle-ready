import 'dart:math' as math;

import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter/material.dart';

class FitnessChart extends StatefulWidget {
  const FitnessChart({
    required this.points,
    this.chartHeight = 240,
    this.showHelp = true,
    super.key,
  });
  final List<FitnessPoint> points;
  final double chartHeight;
  final bool showHelp;

  @override
  State<FitnessChart> createState() => _FitnessChartState();
}

class _FitnessChartState extends State<FitnessChart> {
  int days = 56;
  int? selectedIndex;

  List<FitnessPoint> get visible =>
      widget.points.skip(math.max(0, widget.points.length - days)).toList();

  @override
  Widget build(BuildContext context) {
    final points = visible;
    final selected = points.isEmpty
        ? null
        : points[
            (selectedIndex ?? points.length - 1).clamp(0, points.length - 1)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Training history & forecast',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 28, label: Text('4w')),
                ButtonSegment(value: 56, label: Text('8w')),
                ButtonSegment(value: 90, label: Text('3m')),
              ],
              selected: {days},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() {
                days = value.first;
                selectedIndex = null;
              }),
            ),
          ]),
          const SizedBox(height: 12),
          if (selected != null) _SelectedPoint(point: selected),
          const SizedBox(height: 10),
          SizedBox(
            height: widget.chartHeight,
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _selectAt(
                  details.localPosition.dx,
                  constraints.maxWidth,
                  points.length,
                ),
                onHorizontalDragStart: (details) => _selectAt(
                  details.localPosition.dx,
                  constraints.maxWidth,
                  points.length,
                ),
                onHorizontalDragUpdate: (details) => _selectAt(
                  details.localPosition.dx,
                  constraints.maxWidth,
                  points.length,
                ),
                child: CustomPaint(
                  painter: _FitnessPainter(
                    points: points,
                    selectedIndex:
                        selectedIndex ?? math.max(0, points.length - 1),
                    fitnessColor: const Color(0xFFE64A4A),
                    fatigueColor: const Color(0xFF9B6DFF),
                    formColor: const Color(0xFFFFC928),
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Wrap(spacing: 14, runSpacing: 6, children: [
            _Legend(color: Color(0xFFE64A4A), label: 'Fitness'),
            _Legend(color: Color(0xFF9B6DFF), label: 'Fatigue'),
            _Legend(color: Color(0xFFFFC928), label: 'Form'),
            _Legend(color: Colors.white54, label: 'Dashed = planned'),
          ]),
          if (widget.showHelp) ...[
            const SizedBox(height: 8),
            Text(
                'Tap or drag across the chart to inspect any day. Future values use planned load and will change when the calendar changes.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }

  void _selectAt(double localX, double totalWidth, int pointCount) {
    if (pointCount == 0) return;
    const left = 38.0;
    final width = totalWidth - left - 8;
    final ratio = ((localX - left) / width).clamp(0.0, 1.0);
    final next = (ratio * (pointCount - 1)).round();
    if (next != selectedIndex) setState(() => selectedIndex = next);
  }
}

class _SelectedPoint extends StatelessWidget {
  const _SelectedPoint({required this.point});
  final FitnessPoint point;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Value('${point.date.day}/${point.date.month}',
              point.isForecast ? 'Forecast' : 'Date'),
          _Value(point.load.toStringAsFixed(0), 'Load'),
          _Value(point.fitness.toStringAsFixed(1), 'Fitness'),
          _Value(point.fatigue.toStringAsFixed(1), 'Fatigue'),
          _Value(point.form.toStringAsFixed(1), 'Form'),
        ]),
      );
}

class _Value extends StatelessWidget {
  const _Value(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 4, color: color),
        const SizedBox(width: 4),
        Text(label),
      ]);
}

class _FitnessPainter extends CustomPainter {
  const _FitnessPainter({
    required this.points,
    required this.selectedIndex,
    required this.fitnessColor,
    required this.fatigueColor,
    required this.formColor,
  });
  final List<FitnessPoint> points;
  final int selectedIndex;
  final Color fitnessColor;
  final Color fatigueColor;
  final Color formColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const left = 38.0;
    const top = 8.0;
    const bottom = 24.0;
    final width = size.width - left - 8;
    final height = size.height - top - bottom;
    final maxValue =
        points.expand((p) => [p.fitness, p.fatigue]).fold<double>(10, math.max);
    final gridPaint = Paint()..color = Colors.grey.withValues(alpha: .22);
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade600);
    for (var i = 0; i <= 4; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
      _text(canvas, '${(maxValue * (1 - i / 4)).round()}', Offset(0, y - 6),
          labelStyle);
    }
    double x(int i) => left + i / (points.length - 1) * width;
    double y(double value) => top + height - value / maxValue * height;
    void line(double Function(FitnessPoint) value, Color color, double stroke) {
      final path = Path();
      final forecastIndex = points.indexWhere((point) => point.isForecast);
      final actualEnd = forecastIndex < 0 ? points.length : forecastIndex;
      for (var i = 0; i < actualEnd; i++) {
        final point = Offset(x(i), y(math.max(0, value(points[i]))));
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = stroke
            ..style = PaintingStyle.stroke);
      if (forecastIndex >= 0) {
        final projected = <Offset>[];
        if (forecastIndex > 0) {
          projected.add(Offset(x(forecastIndex - 1),
              y(math.max(0, value(points[forecastIndex - 1])))));
        }
        for (var i = forecastIndex; i < points.length; i++) {
          projected.add(Offset(x(i), y(math.max(0, value(points[i])))));
        }
        _dashedLine(canvas, projected, color, stroke);
      }
    }

    line((p) => p.fitness, fitnessColor, 3);
    line((p) => p.fatigue, fatigueColor, 2);
    line((p) => p.form, formColor, 2);
    final selectedX = x(selectedIndex.clamp(0, points.length - 1));
    canvas.drawLine(
        Offset(selectedX, top),
        Offset(selectedX, top + height),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1);
    for (final index in [0, points.length ~/ 2, points.length - 1]) {
      final date = points[index].date;
      _text(canvas, '${date.day}/${date.month}',
          Offset(x(index) - 12, top + height + 6), labelStyle);
    }
  }

  void _dashedLine(
      Canvas canvas, List<Offset> points, Color color, double stroke) {
    final paint = Paint()
      ..color = color.withValues(alpha: .8)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      final distance = (end - start).distance;
      if (distance == 0) continue;
      final direction = (end - start) / distance;
      for (var travelled = 0.0; travelled < distance; travelled += 8) {
        final dashEnd = math.min(travelled + 4, distance);
        canvas.drawLine(
          start + direction * travelled,
          start + direction * dashEnd,
          paint,
        );
      }
    }
  }

  void _text(Canvas canvas, String value, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FitnessPainter old) =>
      old.points != points || old.selectedIndex != selectedIndex;
}
