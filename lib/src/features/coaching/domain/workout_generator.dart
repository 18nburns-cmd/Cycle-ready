import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';

class WorkoutGenerationContext {
  const WorkoutGenerationContext({
    required this.id,
    required this.day,
    required this.durationMinutes,
    required this.targetLoad,
    required this.reason,
    required this.confidence,
    this.learnedAdjustment,
  });

  final String id;
  final DateTime day;
  final int durationMinutes;
  final int targetLoad;
  final String reason;
  final double confidence;
  final LearnedWorkoutAdjustment? learnedAdjustment;
}

class WarmUpGenerator {
  const WarmUpGenerator();

  WorkoutStep generate({bool highIntensity = false}) => WorkoutStep(
        name: 'Progressive warm up',
        durationSeconds: highIntensity ? 900 : 600,
        powerLowPercent: 45,
        powerHighPercent: highIntensity ? 75 : 65,
        cadenceLow: 80,
        cadenceHigh: 100,
        rpe: 3,
      );
}

class CoolDownGenerator {
  const CoolDownGenerator();

  WorkoutStep generate() => const WorkoutStep(
        name: 'Cool down',
        durationSeconds: 600,
        powerLowPercent: 40,
        powerHighPercent: 55,
        rpe: 2,
      );
}

class WorkoutGenerator {
  const WorkoutGenerator();

  StructuredWorkout recovery(WorkoutGenerationContext context) =>
      _generate(context, 'recovery', 'Recovery spin');

  StructuredWorkout endurance(WorkoutGenerationContext context) =>
      _generate(context, 'endurance', 'Aerobic endurance');

  StructuredWorkout tempo(WorkoutGenerationContext context) =>
      _generate(context, 'tempo', 'Tempo · 3 × 12 min');

  StructuredWorkout sweetSpot(WorkoutGenerationContext context) =>
      _generate(context, 'sweetSpot', 'Sweet spot · 3 × 12 min');

  StructuredWorkout threshold(WorkoutGenerationContext context) =>
      _generate(context, 'threshold', 'Threshold · 4 × 8 min');

  StructuredWorkout vo2Max(WorkoutGenerationContext context) =>
      _generate(context, 'vo2Max', 'VO2 max · 5 × 4 min');

  StructuredWorkout anaerobic(WorkoutGenerationContext context) =>
      _generate(context, 'anaerobic', 'Anaerobic capacity · 8 × 1 min');

  StructuredWorkout sprint(WorkoutGenerationContext context) =>
      _generate(context, 'sprint', 'Sprint · 8 × 12 sec');

  StructuredWorkout climbing(WorkoutGenerationContext context) =>
      _generate(context, 'climbing', 'Climbing strength · 4 × 8 min');

  StructuredWorkout _generate(
    WorkoutGenerationContext context,
    String type,
    String title,
  ) =>
      buildStructuredWorkout(
        id: context.id,
        day: context.day,
        sessionType: type,
        title: title,
        requestedMinutes: (context.durationMinutes *
                (context.learnedAdjustment?.durationMultiplier ?? 1))
            .round(),
        targetLoad: (context.targetLoad *
                (context.learnedAdjustment?.loadMultiplier ?? 1))
            .round(),
        selectionReason: context.learnedAdjustment == null
            ? context.reason
            : '${context.reason} ${context.learnedAdjustment!.reason}',
        confidence: context.learnedAdjustment == null
            ? context.confidence
            : (context.confidence * .7 +
                    context.learnedAdjustment!.confidence * .3)
                .clamp(0, 1),
      );
}

class WorkoutValidationResult {
  const WorkoutValidationResult(this.errors);

  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class WorkoutValidator {
  const WorkoutValidator();

  WorkoutValidationResult validate(StructuredWorkout workout) {
    final errors = <String>[];
    if (workout.id.trim().isEmpty) errors.add('Workout id is required.');
    if (workout.steps.isEmpty) {
      errors.add('At least one workout step is required.');
    }
    if (workout.confidence < 0 || workout.confidence > 1) {
      errors.add('Confidence must be between 0 and 1.');
    }
    for (final step in workout.steps) {
      if (step.durationSeconds <= 0) {
        errors.add('${step.name} must have a positive duration.');
      }
      if (step.powerLowPercent < 0 ||
          step.powerHighPercent < step.powerLowPercent) {
        errors.add('${step.name} has an invalid power range.');
      }
      if (step.repetitions <= 0 || step.recoverySeconds < 0) {
        errors.add('${step.name} has invalid repetition settings.');
      }
    }
    return WorkoutValidationResult(List.unmodifiable(errors));
  }
}

abstract interface class WorkoutExporter {
  String get format;
  Future<List<int>> export(StructuredWorkout workout);
}
