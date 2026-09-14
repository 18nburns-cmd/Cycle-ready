/// Provider-neutral identifiers and relationships for CycleReady workouts.
///
/// These types deliberately contain no database, UI or provider concepts so
/// the same catalogue entry can be planned, analysed and exported unchanged.
enum WorkoutFamily {
  recovery,
  endurance,
  longEndurance,
  tempo,
  sweetSpot,
  threshold,
  overUnder,
  vo2Max,
  anaerobic,
  sprint,
  neuromuscular,
  cadence,
  climbingEndurance,
  strengthEndurance,
  raceSimulation,
  fatigueResistance,
}

enum WorkoutDifficulty { introductory, developing, advanced }

enum WorkoutDurationClass { short, standard, extended }

enum WorkoutCataloguePhase {
  foundation,
  build,
  peak,
  specific,
  taper,
  recovery,
  maintenance,
}

enum WorkoutTerrain { any, flat, rolling, sustainedClimb }

enum WorkoutEquipment { bicycle, powerMeter, heartRateMonitor, indoorTrainer }

enum AdaptationTarget {
  activeRecovery,
  aerobicEfficiency,
  aerobicDurability,
  muscularEndurance,
  lactateClearance,
  thresholdPower,
  maximalAerobicPower,
  anaerobicCapacity,
  neuromuscularPower,
  pedallingEconomy,
  raceSpecificity,
  fatigueResistance,
}

enum WorkoutStepRole { warmUp, work, recovery, coolDown }

class WorkoutCatalogueStep {
  const WorkoutCatalogueStep({
    required this.role,
    required this.durationSeconds,
    required this.powerLowPercent,
    required this.powerHighPercent,
    this.repetitions = 1,
    this.cadenceLow,
    this.cadenceHigh,
  });

  final WorkoutStepRole role;
  final int durationSeconds;
  final int powerLowPercent;
  final int powerHighPercent;
  final int repetitions;
  final int? cadenceLow;
  final int? cadenceHigh;
}

class WorkoutSuccessCriterion {
  const WorkoutSuccessCriterion({
    required this.metric,
    required this.minimum,
    required this.maximum,
    required this.unit,
  }) : assert(minimum <= maximum);

  final String metric;
  final double minimum;
  final double maximum;
  final String unit;
}

class WorkoutVariantId {
  WorkoutVariantId._(this.value);

  factory WorkoutVariantId.parse(String value) {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*-v[1-9][0-9]*$').hasMatch(value)) {
      throw FormatException('Invalid workout variant id: $value');
    }
    return WorkoutVariantId._(value);
  }

  factory WorkoutVariantId.compose({
    required WorkoutFamily family,
    required String variant,
    int version = 1,
  }) {
    final normalized = variant
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (normalized.isEmpty || version < 1) {
      throw ArgumentError('Variant and version must form a stable id.');
    }
    return WorkoutVariantId.parse(
      '${family.name.toLowerCase()}-$normalized-v$version',
    );
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is WorkoutVariantId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class WorkoutVariant {
  WorkoutVariant({
    required this.id,
    required this.family,
    required this.name,
    required this.difficulty,
    required this.durationMinutes,
    required this.adaptationTarget,
    required this.estimatedRecoveryHours,
    this.cadenceRange,
    this.terrain = WorkoutTerrain.any,
    this.requiredEquipment = const {WorkoutEquipment.bicycle},
    this.successCriteria = const [],
    this.steps = const [],
    this.phases = const {},
    this.durationClass = WorkoutDurationClass.standard,
  })  : assert(durationMinutes > 0),
        assert(estimatedRecoveryHours >= 0),
        assert(cadenceRange == null || cadenceRange.$1 <= cadenceRange.$2);

  final WorkoutVariantId id;
  final WorkoutFamily family;
  final String name;
  final WorkoutDifficulty difficulty;
  final int durationMinutes;
  final WorkoutDurationClass durationClass;
  final AdaptationTarget adaptationTarget;
  final int estimatedRecoveryHours;
  final (int, int)? cadenceRange;
  final WorkoutTerrain terrain;
  final Set<WorkoutEquipment> requiredEquipment;
  final List<WorkoutSuccessCriterion> successCriteria;
  final List<WorkoutCatalogueStep> steps;
  final Set<WorkoutCataloguePhase> phases;
}

class WorkoutProgression {
  const WorkoutProgression({
    required this.from,
    required this.to,
  });

  final WorkoutVariantId from;
  final WorkoutVariantId to;

  bool get isSelfReference => from == to;
}
