import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/activities/domain/workout_execution.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';

WorkoutExecutionAnalysis buildWorkoutExecutionAnalysis({
  required PlannedSession planned,
  required int ftp,
  required Iterable<ActivitySample> samples,
}) {
  final workout = buildStructuredWorkout(
    id: planned.day.toIso8601String(),
    day: planned.day,
    sessionType: planned.sessionType,
    title: planned.title,
    requestedMinutes: planned.durationMinutes,
    targetLoad: planned.targetLoad,
  );
  final expected = <ExpectedWorkoutSegment>[];
  var elapsed = 0;
  var workNumber = 0;
  for (final segment in workoutProfile(workout)) {
    if (segment.kind == WorkoutSegmentKind.work) workNumber++;
    expected.add(ExpectedWorkoutSegment(
      label: segment.kind == WorkoutSegmentKind.work
          ? '${segment.label} $workNumber'
          : segment.label,
      startSeconds: elapsed,
      durationSeconds: segment.durationSeconds,
      lowWatts: (ftp * segment.lowPercent / 100).round(),
      highWatts: (ftp * segment.highPercent / 100).round(),
      isWork: segment.kind == WorkoutSegmentKind.work,
    ));
    elapsed += segment.durationSeconds;
  }
  return analyseWorkoutExecution(
    segments: expected,
    samples: samples.map(
      (sample) => ExecutionPowerSample(
        elapsedSeconds: sample.elapsedSeconds,
        watts: sample.power,
      ),
    ),
  );
}
