import 'package:cycle_ready/src/features/activities/domain/workout_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const segments = [
    ExpectedWorkoutSegment(
      label: 'Threshold 1',
      startSeconds: 60,
      durationSeconds: 60,
      lowWatts: 240,
      highWatts: 260,
      isWork: true,
    ),
    ExpectedWorkoutSegment(
      label: 'Threshold 2',
      startSeconds: 180,
      durationSeconds: 60,
      lowWatts: 240,
      highWatts: 260,
      isWork: true,
    ),
  ];

  test('reports target accuracy and fade across completed work intervals', () {
    final samples = <ExecutionPowerSample>[
      for (var second = 60; second < 120; second++)
        ExecutionPowerSample(elapsedSeconds: second, watts: 250),
      for (var second = 180; second < 240; second++)
        ExecutionPowerSample(elapsedSeconds: second, watts: 225),
    ];

    final result = analyseWorkoutExecution(
      segments: segments,
      samples: samples,
    );

    expect(result.isReliable, isTrue);
    expect(result.completedIntervals, 1);
    expect(result.totalIntervals, 2);
    expect(result.targetAccuracy, .5);
    expect(result.fadePercent, closeTo(-10, .01));
    expect(result.summary, contains('1 of 2'));
    expect(result.summary, contains('Threshold 2 averaged 225 W'));
  });

  test('does not judge intervals when power coverage is incomplete', () {
    final result = analyseWorkoutExecution(
      segments: segments,
      samples: const [ExecutionPowerSample(elapsedSeconds: 60, watts: 250)],
    );

    expect(result.isReliable, isFalse);
    expect(result.intervals.first.status, IntervalExecutionStatus.unavailable);
    expect(result.summary, contains('not complete enough'));
  });
}
