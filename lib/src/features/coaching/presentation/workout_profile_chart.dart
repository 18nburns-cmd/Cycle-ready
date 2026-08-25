import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:flutter/material.dart';

class WorkoutProfileChart extends StatelessWidget {
  const WorkoutProfileChart({
    required this.workout,
    this.height = 112,
    super.key,
  });

  final StructuredWorkout workout;
  final double height;

  @override
  Widget build(BuildContext context) {
    final segments = workoutProfile(workout);
    return Semantics(
      label: 'Workout intensity profile with ${segments.length} segments',
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: CustomPaint(
          painter: _WorkoutProfilePainter(
            segments: segments,
            gridColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _WorkoutProfilePainter extends CustomPainter {
  const _WorkoutProfilePainter({
    required this.segments,
    required this.gridColor,
  });

  final List<WorkoutProfileSegment> segments;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final total =
        segments.fold<int>(0, (sum, segment) => sum + segment.durationSeconds);
    if (total <= 0) return;

    final grid = Paint()
      ..color = gridColor.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (final percent in [50, 100, 150]) {
      final y = size.height - percent / 200 * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    var elapsed = 0;
    for (final segment in segments) {
      final left = elapsed / total * size.width;
      elapsed += segment.durationSeconds;
      final right = elapsed / total * size.width;
      final top =
          size.height - segment.highPercent.clamp(0, 200) / 200 * size.height;
      final bottom =
          size.height - segment.lowPercent.clamp(0, 200) / 200 * size.height;
      final color = switch (segment.kind) {
        WorkoutSegmentKind.warmup => const Color(0xFF57C7E8),
        WorkoutSegmentKind.work => _intensityColor(segment.highPercent),
        WorkoutSegmentKind.recovery => const Color(0xFF61D7C4),
        WorkoutSegmentKind.cooldown => const Color(0xFF57C7E8),
      };
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left + 1,
          top,
          (right - 1).clamp(left + 2, size.width),
          bottom.clamp(top + 4, size.height),
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      // Fill to the baseline with a subtle version of the target colour so
      // short efforts remain visible without misrepresenting their target.
      canvas.drawRect(
        Rect.fromLTRB(left + 1, bottom, right - 1, size.height),
        Paint()..color = color.withValues(alpha: .18),
      );
    }
  }

  Color _intensityColor(int percent) => switch (percent) {
        >= 130 => const Color(0xFFFF5C70),
        >= 105 => const Color(0xFFFFB84D),
        >= 88 => const Color(0xFF35D99A),
        _ => const Color(0xFF57C7E8),
      };

  @override
  bool shouldRepaint(covariant _WorkoutProfilePainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.gridColor != gridColor;
}
