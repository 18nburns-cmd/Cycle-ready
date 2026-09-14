import 'dart:math' as math;

import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';

enum TrainingPhase {
  foundation,
  base,
  build,
  specialty,
  taper,
  recoveryTransition,
}

enum CapabilityDimension {
  aerobicEndurance,
  durability,
  tempo,
  threshold,
  vo2max,
  anaerobicCapacity,
  sprintPower,
  climbingEndurance,
  muscularEndurance,
  fatigueResistance,
  repeatability,
}

enum CapabilityTrend { declining, stable, improving }

enum CyclingEventType { sportive, granFondo, timeTrial, roadRace, audax, other }

enum EventTerrain { flat, rolling, hilly, mountainous }

class EventDemandInput {
  const EventDemandInput({
    required this.type,
    required this.distanceKm,
    required this.expectedDurationHours,
    required this.elevationMetres,
    required this.terrain,
  })  : assert(distanceKm > 0),
        assert(expectedDurationHours > 0),
        assert(elevationMetres >= 0);

  final CyclingEventType type;
  final double distanceKm;
  final double expectedDurationHours;
  final int elevationMetres;
  final EventTerrain terrain;
}

class EventDemandProfile {
  EventDemandProfile({required Map<CapabilityDimension, double> demands})
      : demands = Map.unmodifiable({
          for (final dimension in CapabilityDimension.values)
            dimension: _score(demands[dimension] ?? 0),
        });

  final Map<CapabilityDimension, double> demands;

  double operator [](CapabilityDimension dimension) => demands[dimension]!;
}

class EventDemandModel {
  const EventDemandModel();

  EventDemandProfile calculate(EventDemandInput input) {
    final duration = (input.expectedDurationHours / 8).clamp(0.0, 1.0);
    final distance = (input.distanceKm / 200).clamp(0.0, 1.0);
    final climbing = (input.elevationMetres / 3500).clamp(0.0, 1.0);
    final terrain = switch (input.terrain) {
      EventTerrain.flat => 0.1,
      EventTerrain.rolling => 0.4,
      EventTerrain.hilly => 0.75,
      EventTerrain.mountainous => 1.0,
    };
    final competition = switch (input.type) {
      CyclingEventType.roadRace => 1.0,
      CyclingEventType.timeTrial => .75,
      CyclingEventType.granFondo => .55,
      CyclingEventType.sportive => .35,
      CyclingEventType.audax => .15,
      CyclingEventType.other => .3,
    };
    final steady = input.type == CyclingEventType.timeTrial ? 1.0 : .55;
    final ultra = input.type == CyclingEventType.audax ? 1.0 : duration;

    return EventDemandProfile(demands: {
      CapabilityDimension.aerobicEndurance: 50 + 30 * duration + 20 * distance,
      CapabilityDimension.durability: 35 + 35 * duration + 30 * ultra,
      CapabilityDimension.tempo: 35 + 30 * duration + 20 * steady,
      CapabilityDimension.threshold:
          30 + 25 * competition + 20 * climbing + 15 * steady,
      CapabilityDimension.vo2max: 20 + 35 * competition + 20 * terrain,
      CapabilityDimension.anaerobicCapacity: 10 + 45 * competition,
      CapabilityDimension.sprintPower: 5 + 55 * competition,
      CapabilityDimension.climbingEndurance: 10 + 55 * climbing + 30 * terrain,
      CapabilityDimension.muscularEndurance: 25 + 30 * duration + 30 * terrain,
      CapabilityDimension.fatigueResistance: 25 + 40 * duration + 30 * ultra,
      CapabilityDimension.repeatability: 20 + 45 * competition + 20 * terrain,
    });
  }
}

class AthleteCapability {
  const AthleteCapability({
    required this.score,
    required this.confidence,
    required this.trend,
    required this.evidenceCount,
    required this.lastUpdated,
  })  : assert(score >= 0 && score <= 100),
        assert(confidence >= 0 && confidence <= 1),
        assert(evidenceCount >= 0);

  final double score;
  final double confidence;
  final CapabilityTrend trend;
  final int evidenceCount;
  final DateTime lastUpdated;
}

class AthleteCapabilityProfile {
  AthleteCapabilityProfile({
    required Map<CapabilityDimension, AthleteCapability> capabilities,
  }) : capabilities = Map.unmodifiable(capabilities);

  final Map<CapabilityDimension, AthleteCapability> capabilities;
}

class CapabilityGap {
  const CapabilityGap({
    required this.dimension,
    required this.demand,
    required this.capability,
    required this.rawGap,
    required this.priority,
    required this.confidence,
  });

  final CapabilityDimension dimension;
  final double demand;
  final double capability;
  final double rawGap;
  final double priority;
  final double confidence;
}

class StrategicTrainingBlock {
  StrategicTrainingBlock({
    required this.phase,
    required this.primaryAdaptation,
    required this.secondaryAdaptation,
    required Set<CapabilityDimension> maintenanceAdaptations,
    required this.startDate,
    required this.plannedEndDate,
    required this.minimumDurationDays,
    required this.maximumDurationDays,
    required this.reasonCodes,
  }) : maintenanceAdaptations = Set.unmodifiable(maintenanceAdaptations);

  final TrainingPhase phase;
  final CapabilityDimension primaryAdaptation;
  final CapabilityDimension secondaryAdaptation;
  final Set<CapabilityDimension> maintenanceAdaptations;
  final DateTime startDate;
  final DateTime plannedEndDate;
  final int minimumDurationDays;
  final int maximumDurationDays;
  final List<String> reasonCodes;
}

class WorkoutFamilyEligibility {
  const WorkoutFamilyEligibility({
    required this.family,
    required this.weight,
    required this.reasonCodes,
  });

  final WorkoutFamily family;
  final double weight;
  final List<String> reasonCodes;

  bool get isEligible => weight > 0;
}

class WorkoutFamilyEligibilityEngine {
  const WorkoutFamilyEligibilityEngine();

  List<WorkoutFamilyEligibility> evaluate({
    required StrategicTrainingBlock block,
    required EventDemandProfile demands,
  }) {
    final results = <WorkoutFamilyEligibility>[];
    for (final family in WorkoutFamily.values) {
      final adaptation = _familyAdaptation(family);
      var weight = _phaseWeight(block.phase, family);
      final reasons = <String>['PHASE_${block.phase.name.toUpperCase()}'];
      if (adaptation == block.primaryAdaptation) {
        weight *= 1.5;
        reasons.add('PRIMARY_ADAPTATION');
      } else if (adaptation == block.secondaryAdaptation) {
        weight *= 1.25;
        reasons.add('SECONDARY_ADAPTATION');
      } else if (block.maintenanceAdaptations.contains(adaptation)) {
        reasons.add('MAINTENANCE_ADAPTATION');
      }
      final eventRelevance = demands[adaptation] / 100;
      weight *= .5 + eventRelevance * .5;
      if (eventRelevance >= .75) reasons.add('EVENT_DEMAND_HIGH');
      results.add(WorkoutFamilyEligibility(
        family: family,
        weight: weight.clamp(0, 1).toDouble(),
        reasonCodes: List.unmodifiable(reasons),
      ));
    }
    results.sort((a, b) {
      final weight = b.weight.compareTo(a.weight);
      return weight != 0 ? weight : a.family.index.compareTo(b.family.index);
    });
    return List.unmodifiable(results);
  }

  double _phaseWeight(TrainingPhase phase, WorkoutFamily family) {
    if (family == WorkoutFamily.recovery) return 1;
    return switch (phase) {
      TrainingPhase.foundation => switch (family) {
          WorkoutFamily.endurance || WorkoutFamily.longEndurance => 1,
          WorkoutFamily.tempo => .7,
          WorkoutFamily.sprint || WorkoutFamily.neuromuscular => .5,
          WorkoutFamily.climbingEndurance => .4,
          WorkoutFamily.sweetSpot => .3,
          WorkoutFamily.threshold => .2,
          WorkoutFamily.vo2Max => .15,
          WorkoutFamily.fatigueResistance => .1,
          WorkoutFamily.overUnder || WorkoutFamily.anaerobic => .05,
          WorkoutFamily.cadence || WorkoutFamily.strengthEndurance => .45,
          WorkoutFamily.raceSimulation => 0,
          WorkoutFamily.recovery => 1,
        },
      TrainingPhase.base => switch (family) {
          WorkoutFamily.endurance ||
          WorkoutFamily.longEndurance ||
          WorkoutFamily.tempo =>
            1,
          WorkoutFamily.sweetSpot || WorkoutFamily.sprint => .75,
          WorkoutFamily.threshold || WorkoutFamily.climbingEndurance => .6,
          WorkoutFamily.vo2Max || WorkoutFamily.overUnder => .35,
          WorkoutFamily.anaerobic || WorkoutFamily.raceSimulation => .15,
          _ => .5,
        },
      TrainingPhase.build => switch (family) {
          WorkoutFamily.longEndurance ||
          WorkoutFamily.sweetSpot ||
          WorkoutFamily.threshold ||
          WorkoutFamily.overUnder ||
          WorkoutFamily.vo2Max ||
          WorkoutFamily.climbingEndurance ||
          WorkoutFamily.fatigueResistance =>
            .85,
          WorkoutFamily.endurance => .7,
          WorkoutFamily.anaerobic => .45,
          _ => .55,
        },
      TrainingPhase.specialty => switch (family) {
          WorkoutFamily.raceSimulation ||
          WorkoutFamily.longEndurance ||
          WorkoutFamily.fatigueResistance =>
            1,
          WorkoutFamily.endurance => .65,
          _ => .6,
        },
      TrainingPhase.taper => switch (family) {
          WorkoutFamily.endurance || WorkoutFamily.cadence => .8,
          WorkoutFamily.threshold || WorkoutFamily.vo2Max => .4,
          WorkoutFamily.raceSimulation => .2,
          WorkoutFamily.anaerobic || WorkoutFamily.fatigueResistance => 0,
          _ => .3,
        },
      TrainingPhase.recoveryTransition => switch (family) {
          WorkoutFamily.endurance || WorkoutFamily.cadence => .35,
          _ => 0,
        },
    };
  }

  CapabilityDimension _familyAdaptation(WorkoutFamily family) =>
      switch (family) {
        WorkoutFamily.recovery ||
        WorkoutFamily.endurance ||
        WorkoutFamily.cadence =>
          CapabilityDimension.aerobicEndurance,
        WorkoutFamily.longEndurance => CapabilityDimension.durability,
        WorkoutFamily.tempo ||
        WorkoutFamily.sweetSpot =>
          CapabilityDimension.tempo,
        WorkoutFamily.threshold ||
        WorkoutFamily.overUnder =>
          CapabilityDimension.threshold,
        WorkoutFamily.vo2Max => CapabilityDimension.vo2max,
        WorkoutFamily.anaerobic => CapabilityDimension.anaerobicCapacity,
        WorkoutFamily.sprint ||
        WorkoutFamily.neuromuscular =>
          CapabilityDimension.sprintPower,
        WorkoutFamily.climbingEndurance =>
          CapabilityDimension.climbingEndurance,
        WorkoutFamily.strengthEndurance =>
          CapabilityDimension.muscularEndurance,
        WorkoutFamily.raceSimulation ||
        WorkoutFamily.fatigueResistance =>
          CapabilityDimension.fatigueResistance,
      };
}

class StrategicPlanningInput {
  const StrategicPlanningInput({
    required this.today,
    required this.eventDate,
    required this.demands,
    required this.capabilities,
    this.recentTrainingConsistency = .75,
    this.recoveryTransitionRequired = false,
  }) : assert(recentTrainingConsistency >= 0 && recentTrainingConsistency <= 1);

  final DateTime today;
  final DateTime eventDate;
  final EventDemandProfile demands;
  final AthleteCapabilityProfile capabilities;
  final double recentTrainingConsistency;
  final bool recoveryTransitionRequired;
}

class StrategicTrainingPlanner {
  const StrategicTrainingPlanner();

  List<CapabilityGap> analyseGaps(StrategicPlanningInput input) {
    final gaps = <CapabilityGap>[];
    for (final dimension in CapabilityDimension.values) {
      final capability = input.capabilities.capabilities[dimension];
      final demand = input.demands[dimension];
      final score = capability?.score ?? 50;
      final confidence = capability?.confidence ?? 0;
      final rawGap = math.max(0.0, demand - score);
      // Demand keeps a large gap in a low-value event capability from
      // displacing a smaller but decisive event-specific limitation.
      final priority = rawGap * (demand / 100) * (.5 + confidence * .5);
      gaps.add(CapabilityGap(
        dimension: dimension,
        demand: demand,
        capability: score,
        rawGap: rawGap,
        priority: priority,
        confidence: confidence,
      ));
    }
    gaps.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0
          ? priority
          : a.dimension.index.compareTo(b.dimension.index);
    });
    return List.unmodifiable(gaps);
  }

  TrainingPhase selectPhase(StrategicPlanningInput input) {
    if (input.recoveryTransitionRequired ||
        input.eventDate.isBefore(input.today)) {
      return TrainingPhase.recoveryTransition;
    }
    final days = _date(input.eventDate).difference(_date(input.today)).inDays;
    final weeks = days / 7;
    if (weeks <= 2) return TrainingPhase.taper;
    if (weeks <= 8) return TrainingPhase.specialty;
    if (weeks <= 16) return TrainingPhase.build;
    if (weeks <= 32 && input.recentTrainingConsistency >= .6) {
      return TrainingPhase.base;
    }
    return TrainingPhase.foundation;
  }

  StrategicTrainingBlock buildBlock(StrategicPlanningInput input) {
    final phase = selectPhase(input);
    final gaps = analyseGaps(input);
    final development = gaps
        .where((gap) => gap.demand >= 35)
        .map((gap) => gap.dimension)
        .toList();
    final defaults = _phaseDefaults(phase);
    final primary = development.firstOrNull ?? defaults.$1;
    final secondary =
        development.where((item) => item != primary).firstOrNull ?? defaults.$2;
    final maintenance = CapabilityDimension.values
        .where((dimension) =>
            dimension != primary &&
            dimension != secondary &&
            input.demands[dimension] >= 50)
        .toSet();
    final duration = switch (phase) {
      TrainingPhase.foundation => 28,
      TrainingPhase.base || TrainingPhase.build => 21,
      TrainingPhase.specialty => 14,
      TrainingPhase.taper => math.max(
          1,
          _date(input.eventDate).difference(_date(input.today)).inDays,
        ),
      TrainingPhase.recoveryTransition => 7,
    };
    final eventBoundEnd = _date(input.today).add(Duration(days: duration - 1));
    final end = eventBoundEnd.isAfter(_date(input.eventDate))
        ? _date(input.eventDate)
        : eventBoundEnd;
    return StrategicTrainingBlock(
      phase: phase,
      primaryAdaptation: primary,
      secondaryAdaptation: secondary,
      maintenanceAdaptations: maintenance,
      startDate: _date(input.today),
      plannedEndDate: end,
      minimumDurationDays: phase == TrainingPhase.taper ? 1 : 7,
      maximumDurationDays: duration,
      reasonCodes: [
        'PHASE_${phase.name.toUpperCase()}',
        'BLOCK_${primary.name.toUpperCase()}',
        'CAPABILITY_GAP_${primary.name.toUpperCase()}',
      ],
    );
  }

  (CapabilityDimension, CapabilityDimension) _phaseDefaults(
    TrainingPhase phase,
  ) =>
      switch (phase) {
        TrainingPhase.foundation || TrainingPhase.base => (
            CapabilityDimension.aerobicEndurance,
            CapabilityDimension.durability,
          ),
        TrainingPhase.build => (
            CapabilityDimension.threshold,
            CapabilityDimension.durability,
          ),
        TrainingPhase.specialty => (
            CapabilityDimension.fatigueResistance,
            CapabilityDimension.repeatability,
          ),
        TrainingPhase.taper => (
            CapabilityDimension.aerobicEndurance,
            CapabilityDimension.threshold,
          ),
        TrainingPhase.recoveryTransition => (
            CapabilityDimension.aerobicEndurance,
            CapabilityDimension.durability,
          ),
      };
}

double _score(double value) => value.clamp(0, 100).toDouble();

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
