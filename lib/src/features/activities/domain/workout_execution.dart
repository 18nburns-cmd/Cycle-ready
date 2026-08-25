enum IntervalExecutionStatus { onTarget, belowTarget, aboveTarget, unavailable }

class ExpectedWorkoutSegment {
  const ExpectedWorkoutSegment({
    required this.label,
    required this.startSeconds,
    required this.durationSeconds,
    required this.lowWatts,
    required this.highWatts,
    required this.isWork,
  });

  final String label;
  final int startSeconds;
  final int durationSeconds;
  final int lowWatts;
  final int highWatts;
  final bool isWork;
}

class ExecutionPowerSample {
  const ExecutionPowerSample({required this.elapsedSeconds, this.watts});

  final int elapsedSeconds;
  final int? watts;
}

class IntervalExecution {
  const IntervalExecution({
    required this.label,
    required this.targetLowWatts,
    required this.targetHighWatts,
    required this.averageWatts,
    required this.coverage,
    required this.status,
  });

  final String label;
  final int targetLowWatts;
  final int targetHighWatts;
  final int? averageWatts;
  final double coverage;
  final IntervalExecutionStatus status;
}

class WorkoutExecutionAnalysis {
  const WorkoutExecutionAnalysis({
    required this.intervals,
    required this.completedIntervals,
    required this.totalIntervals,
    required this.targetAccuracy,
    required this.powerCoverage,
    required this.fadePercent,
    required this.isReliable,
  });

  final List<IntervalExecution> intervals;
  final int completedIntervals;
  final int totalIntervals;
  final double targetAccuracy;
  final double powerCoverage;
  final double? fadePercent;
  final bool isReliable;

  String get summary {
    if (!isReliable) {
      return 'The power trace was not complete enough to judge individual workout intervals reliably.';
    }
    final fade = fadePercent == null
        ? ''
        : fadePercent! < -5
            ? ' Average interval power faded ${fadePercent!.abs().toStringAsFixed(1)}% from first to last.'
            : ' Power was sustained from the first interval to the last.';
    final misses = intervals
        .where((interval) =>
            interval.status == IntervalExecutionStatus.belowTarget ||
            interval.status == IntervalExecutionStatus.aboveTarget)
        .take(2)
        .map((interval) =>
            '${interval.label} averaged ${interval.averageWatts} W against ${interval.targetLowWatts}â€“${interval.targetHighWatts} W')
        .toList();
    final detail = misses.isEmpty ? '' : ' ${misses.join('; ')}.';
    return '$completedIntervals of $totalIntervals work intervals met the prescribed range, with ${(targetAccuracy * 100).round()}% target accuracy.$detail$fade';
  }
}

WorkoutExecutionAnalysis analyseWorkoutExecution({
  required List<ExpectedWorkoutSegment> segments,
  required Iterable<ExecutionPowerSample> samples,
}) {
  final work = segments.where((segment) => segment.isWork).toList();
  final bySecond = <int, int>{
    for (final sample in samples)
      if (sample.elapsedSeconds >= 0 && (sample.watts ?? 0) > 0)
        sample.elapsedSeconds: sample.watts!,
  };
  final intervals = <IntervalExecution>[];
  for (final segment in work) {
    final powers = <int>[];
    for (var second = segment.startSeconds;
        second < segment.startSeconds + segment.durationSeconds;
        second++) {
      final watts = bySecond[second];
      if (watts != null) powers.add(watts);
    }
    final coverage = segment.durationSeconds <= 0
        ? 0.0
        : powers.length / segment.durationSeconds;
    final average = powers.isEmpty
        ? null
        : (powers.reduce((a, b) => a + b) / powers.length).round();
    final status = coverage < .7 || average == null
        ? IntervalExecutionStatus.unavailable
        : average < segment.lowWatts * .95
            ? IntervalExecutionStatus.belowTarget
            : average > segment.highWatts * 1.08
                ? IntervalExecutionStatus.aboveTarget
                : IntervalExecutionStatus.onTarget;
    intervals.add(IntervalExecution(
      label: segment.label,
      targetLowWatts: segment.lowWatts,
      targetHighWatts: segment.highWatts,
      averageWatts: average,
      coverage: coverage.clamp(0, 1),
      status: status,
    ));
  }
  final available = intervals
      .where(
          (interval) => interval.status != IntervalExecutionStatus.unavailable)
      .toList();
  final completed = available
      .where((interval) => interval.status == IntervalExecutionStatus.onTarget)
      .length;
  final totalSeconds =
      work.fold<int>(0, (sum, item) => sum + item.durationSeconds);
  var coveredSeconds = 0;
  for (var index = 0; index < work.length; index++) {
    coveredSeconds +=
        (work[index].durationSeconds * intervals[index].coverage).round();
  }
  final powerCoverage = totalSeconds == 0 ? 0.0 : coveredSeconds / totalSeconds;
  final reliable =
      work.isNotEmpty && available.length == work.length && powerCoverage >= .7;
  double? fade;
  if (reliable && available.length >= 2) {
    final first = available.first.averageWatts!;
    final last = available.last.averageWatts!;
    if (first > 0) fade = (last / first - 1) * 100;
  }
  return WorkoutExecutionAnalysis(
    intervals: intervals,
    completedIntervals: completed,
    totalIntervals: work.length,
    targetAccuracy: available.isEmpty ? 0 : completed / available.length,
    powerCoverage: powerCoverage.clamp(0, 1),
    fadePercent: fade,
    isReliable: reliable,
  );
}
