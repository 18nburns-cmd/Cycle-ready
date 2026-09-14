import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_library.dart';

class LocalWorkoutCatalogueRepository implements WorkoutCatalogueRepository {
  LocalWorkoutCatalogueRepository({
    PhaseAwareWorkoutLibrary library = const PhaseAwareWorkoutLibrary(),
    int ftp = 200,
  }) : _variants = _materialize(library, ftp);

  final List<WorkoutVariant> _variants;

  @override
  Future<List<WorkoutVariant>> find(WorkoutCatalogueQuery query) async =>
      List.unmodifiable(_variants.where((variant) {
        if (query.family != null && variant.family != query.family) {
          return false;
        }
        if (query.phase != null && !variant.phases.contains(query.phase)) {
          return false;
        }
        if (query.minimumDurationMinutes != null &&
            variant.durationMinutes < query.minimumDurationMinutes!) {
          return false;
        }
        if (query.maximumDurationMinutes != null &&
            variant.durationMinutes > query.maximumDurationMinutes!) {
          return false;
        }
        if (query.availableEquipment.isNotEmpty &&
            !query.availableEquipment.containsAll(variant.requiredEquipment)) {
          return false;
        }
        return true;
      }));

  @override
  Future<WorkoutVariant?> getById(WorkoutVariantId id) async {
    for (final variant in _variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  @override
  Future<List<WorkoutProgression>> progressionsFor(WorkoutVariantId id) async =>
      const [];

  static List<WorkoutVariant> _materialize(
    PhaseAwareWorkoutLibrary library,
    int ftp,
  ) {
    final variants = <String, WorkoutVariant>{};
    for (final phase in WorkoutLibraryPhase.values) {
      for (final goal in WorkoutLibraryGoal.values) {
        for (final type in SessionType.values.where(
          (value) => value != SessionType.rest,
        )) {
          for (var week = 0; week < 3; week++) {
            for (final longRide in [false, true]) {
              final item = library.select(
                goal: goal,
                phase: phase,
                requestedType: type,
                blockWeek: week,
                ftp: ftp,
                longRide: longRide,
              );
              final family = _family(item.id);
              final id = WorkoutVariantId.compose(
                family: family,
                variant: item.id,
              );
              final existing = variants[id.value];
              variants[id.value] = existing == null
                  ? WorkoutVariant(
                      id: id,
                      family: family,
                      name: item.title,
                      difficulty: WorkoutDifficulty.values[week],
                      durationMinutes: item.durationMinutes,
                      adaptationTarget: _adaptation(family),
                      estimatedRecoveryHours:
                          (item.targetLoad * .45).round().clamp(4, 48),
                      requiredEquipment: const {WorkoutEquipment.bicycle},
                      successCriteria: const [
                        WorkoutSuccessCriterion(
                          metric: 'target_load_completion',
                          minimum: .85,
                          maximum: 1.15,
                          unit: 'ratio',
                        ),
                      ],
                      phases: {_phase(phase)},
                    )
                  : _withPhases(existing, {
                      ...existing.phases,
                      _phase(phase),
                    });
            }
          }
        }
      }
    }
    return List.unmodifiable(variants.values);
  }

  static WorkoutFamily _family(String id) {
    if (id.startsWith('recovery')) return WorkoutFamily.recovery;
    if (id.startsWith('long-endurance')) return WorkoutFamily.longEndurance;
    if (id.startsWith('event-durability')) {
      return WorkoutFamily.fatigueResistance;
    }
    if (id.startsWith('tempo')) return WorkoutFamily.tempo;
    if (id.startsWith('sweet-spot')) return WorkoutFamily.sweetSpot;
    if (id.startsWith('threshold')) return WorkoutFamily.threshold;
    if (id.startsWith('vo2')) return WorkoutFamily.vo2Max;
    return WorkoutFamily.endurance;
  }

  static AdaptationTarget _adaptation(WorkoutFamily family) => switch (family) {
        WorkoutFamily.recovery => AdaptationTarget.activeRecovery,
        WorkoutFamily.endurance => AdaptationTarget.aerobicEfficiency,
        WorkoutFamily.longEndurance => AdaptationTarget.aerobicDurability,
        WorkoutFamily.tempo ||
        WorkoutFamily.sweetSpot ||
        WorkoutFamily.climbingEndurance ||
        WorkoutFamily.strengthEndurance =>
          AdaptationTarget.muscularEndurance,
        WorkoutFamily.threshold => AdaptationTarget.thresholdPower,
        WorkoutFamily.overUnder => AdaptationTarget.lactateClearance,
        WorkoutFamily.vo2Max => AdaptationTarget.maximalAerobicPower,
        WorkoutFamily.anaerobic => AdaptationTarget.anaerobicCapacity,
        WorkoutFamily.sprint ||
        WorkoutFamily.neuromuscular =>
          AdaptationTarget.neuromuscularPower,
        WorkoutFamily.cadence => AdaptationTarget.pedallingEconomy,
        WorkoutFamily.raceSimulation => AdaptationTarget.raceSpecificity,
        WorkoutFamily.fatigueResistance => AdaptationTarget.fatigueResistance,
      };

  static WorkoutCataloguePhase _phase(WorkoutLibraryPhase phase) =>
      WorkoutCataloguePhase.values.byName(phase.name);

  static WorkoutVariant _withPhases(
    WorkoutVariant source,
    Set<WorkoutCataloguePhase> phases,
  ) =>
      WorkoutVariant(
        id: source.id,
        family: source.family,
        name: source.name,
        difficulty: source.difficulty,
        durationMinutes: source.durationMinutes,
        durationClass: source.durationClass,
        adaptationTarget: source.adaptationTarget,
        estimatedRecoveryHours: source.estimatedRecoveryHours,
        cadenceRange: source.cadenceRange,
        terrain: source.terrain,
        requiredEquipment: source.requiredEquipment,
        successCriteria: source.successCriteria,
        steps: source.steps,
        phases: phases,
      );
}
