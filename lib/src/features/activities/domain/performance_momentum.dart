import 'package:cycle_ready/src/features/activities/domain/power_curve_progress.dart';

enum PerformanceMomentumStatus { improving, stable, mixed, declining }

class PerformanceMomentum {
  const PerformanceMomentum({
    required this.status,
    required this.headline,
    required this.explanation,
    required this.averageChangePercent,
    required this.comparisonCount,
  });

  final PerformanceMomentumStatus status;
  final String headline;
  final String explanation;
  final double averageChangePercent;
  final int comparisonCount;
}

PerformanceMomentum? assessPerformanceMomentum(
  Iterable<PowerCurveProgress> progress,
) {
  final values = progress.toList();
  if (values.isEmpty) return null;

  final changes = values.map((item) => item.changePercent).toList();
  final average = changes.reduce((a, b) => a + b) / changes.length;
  final improving = changes.where((value) => value > 2).length;
  final declining = changes.where((value) => value < -2).length;

  if (improving > 0 && declining > 0) {
    return PerformanceMomentum(
      status: PerformanceMomentumStatus.mixed,
      headline: 'Your power profile is changing shape',
      explanation:
          'Some durations improved while others fell. This usually reflects training focus, fatigue or different ride opportunities rather than a simple gain or loss of fitness.',
      averageChangePercent: average,
      comparisonCount: values.length,
    );
  }
  if (improving >= 2 || (values.length == 1 && improving == 1)) {
    return PerformanceMomentum(
      status: PerformanceMomentumStatus.improving,
      headline: 'Power momentum is building',
      explanation:
          'Your recent best efforts are moving upward. Keep the training consistent and protect recovery rather than adding load simply because the curve has improved.',
      averageChangePercent: average,
      comparisonCount: values.length,
    );
  }
  if (declining >= 2 || (values.length == 1 && declining == 1)) {
    return PerformanceMomentum(
      status: PerformanceMomentumStatus.declining,
      headline: 'Recent best power is below your previous block',
      explanation:
          'This can reflect fatigue or a lack of maximal efforts, not necessarily lost fitness. Check readiness, training consistency and comparable session opportunities before changing FTP.',
      averageChangePercent: average,
      comparisonCount: values.length,
    );
  }
  return PerformanceMomentum(
    status: PerformanceMomentumStatus.stable,
    headline: 'Power is holding steady',
    explanation:
        'Your recent curve is within normal variation. Stability can be a positive result during endurance development, recovery weeks or periods without maximal efforts.',
    averageChangePercent: average,
    comparisonCount: values.length,
  );
}
