import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/intervals/domain/intervals_workout.dart';

class IntervalsWorkoutDeliveryProvider implements WorkoutDeliveryProvider {
  const IntervalsWorkoutDeliveryProvider(this.service);

  final IntervalsIcuService service;

  @override
  String get id => 'intervals_icu';

  @override
  Future<WorkoutDeliveryResult> deliver(
      List<StructuredWorkout> workouts) async {
    final count = await service.publishPlannedWorkouts(
      workouts
          .map((workout) => IntervalsPlannedWorkout(
                externalId: workout.id,
                day: workout.scheduledDay,
                name: 'CycleReady - ${workout.title}',
                description: renderIntervalsWorkout(workout),
                durationSeconds: workout.durationSeconds,
              ))
          .toList(),
    );
    return WorkoutDeliveryResult(provider: id, delivered: count);
  }
}

String renderIntervalsWorkout(StructuredWorkout workout) {
  final lines = <String>[];
  for (final step in workout.steps) {
    if (step.repetitions > 1) lines.add('${step.repetitions}x');
    final duration = _duration(step.durationSeconds);
    final target = step.powerLowPercent == step.powerHighPercent
        ? '${step.powerLowPercent}%'
        : '${step.powerLowPercent}-${step.powerHighPercent}%';
    lines.add('- $duration $target ${step.name}');
    if (step.repetitions > 1 && step.recoverySeconds > 0) {
      lines.add(
          '- ${_duration(step.recoverySeconds)} ${step.recoveryPowerPercent}% Recovery');
    }
    lines.add('');
  }
  return lines.join('\n').trim();
}

String _duration(int seconds) =>
    seconds % 60 == 0 ? '${seconds ~/ 60}m' : '${seconds}s';
