import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';

class WorkoutCatalogueValidation {
  const WorkoutCatalogueValidation(this.errors);

  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class WorkoutCatalogueValidator {
  const WorkoutCatalogueValidator();

  WorkoutCatalogueValidation validate(WorkoutVariant variant) {
    final errors = <String>[];
    if (!variant.id.value.startsWith('${variant.family.name.toLowerCase()}-')) {
      errors.add('Variant id must start with its workout family.');
    }
    if (variant.name.trim().isEmpty) errors.add('Variant name is required.');
    if (variant.durationMinutes <= 0) errors.add('Duration must be positive.');
    if (variant.estimatedRecoveryHours < 0) {
      errors.add('Recovery time cannot be negative.');
    }
    final cadence = variant.cadenceRange;
    if (cadence != null &&
        (cadence.$1 < 30 || cadence.$2 > 220 || cadence.$1 > cadence.$2)) {
      errors.add('Variant cadence range is invalid.');
    }
    if (variant.steps.isEmpty) errors.add('Structured steps are required.');
    if (variant.steps.isNotEmpty) {
      if (variant.steps.first.role != WorkoutStepRole.warmUp) {
        errors.add('The first step must be a warm-up.');
      }
      if (variant.steps.last.role != WorkoutStepRole.coolDown) {
        errors.add('The last step must be a cool-down.');
      }
      if (!variant.steps.any((step) => step.role == WorkoutStepRole.work)) {
        errors.add('At least one work step is required.');
      }
    }
    for (final step in variant.steps) {
      if (step.durationSeconds <= 0 || step.repetitions <= 0) {
        errors.add(
            '${step.role.name} step duration and repetitions must be positive.');
      }
      if (step.powerLowPercent < 0 ||
          step.powerLowPercent > step.powerHighPercent ||
          step.powerHighPercent > 250) {
        errors.add('${step.role.name} step power range is invalid.');
      }
      if ((step.cadenceLow == null) != (step.cadenceHigh == null) ||
          (step.cadenceLow != null &&
              (step.cadenceLow! < 30 ||
                  step.cadenceHigh! > 220 ||
                  step.cadenceLow! > step.cadenceHigh!))) {
        errors.add('${step.role.name} step cadence range is invalid.');
      }
    }
    if (variant.steps.isNotEmpty) {
      final structuredSeconds = variant.steps.fold<int>(
        0,
        (total, step) => total + step.durationSeconds * step.repetitions,
      );
      final declaredSeconds = variant.durationMinutes * 60;
      if ((structuredSeconds - declaredSeconds).abs() > 120) {
        errors.add('Structured steps must match the declared total duration.');
      }
    }
    for (final criterion in variant.successCriteria) {
      if (criterion.metric.trim().isEmpty || criterion.unit.trim().isEmpty) {
        errors.add('Success criteria require a metric and unit.');
      }
      if (!criterion.minimum.isFinite || !criterion.maximum.isFinite) {
        errors.add('Success criterion bounds must be finite.');
      }
    }
    return WorkoutCatalogueValidation(List.unmodifiable(errors));
  }
}
