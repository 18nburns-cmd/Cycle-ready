import 'package:cycle_ready/src/features/coaching/domain/strategic_training_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = StrategicTrainingPlanner();
  const demandModel = EventDemandModel();
  final today = DateTime(2026, 9, 12);

  test('long hilly sportive emphasizes endurance durability and climbing', () {
    final demand = demandModel.calculate(const EventDemandInput(
      type: CyclingEventType.sportive,
      distanceKm: 160,
      expectedDurationHours: 7,
      elevationMetres: 2800,
      terrain: EventTerrain.hilly,
    ));

    expect(demand[CapabilityDimension.aerobicEndurance], greaterThan(85));
    expect(demand[CapabilityDimension.durability], greaterThan(85));
    expect(demand[CapabilityDimension.climbingEndurance], greaterThan(70));
    expect(
      demand[CapabilityDimension.anaerobicCapacity],
      lessThan(demand[CapabilityDimension.durability]),
    );
  });

  test('road race raises repeatability and sprint demands over audax', () {
    EventDemandProfile demand(CyclingEventType type) => demandModel.calculate(
          EventDemandInput(
            type: type,
            distanceKm: 120,
            expectedDurationHours: 4,
            elevationMetres: 900,
            terrain: EventTerrain.rolling,
          ),
        );

    expect(
      demand(CyclingEventType.roadRace)[CapabilityDimension.repeatability],
      greaterThan(
        demand(CyclingEventType.audax)[CapabilityDimension.repeatability],
      ),
    );
    expect(
      demand(CyclingEventType.roadRace)[CapabilityDimension.sprintPower],
      greaterThan(
        demand(CyclingEventType.audax)[CapabilityDimension.sprintPower],
      ),
    );
  });

  test('long event eleven months away starts in Foundation', () {
    final input = _input(
      today: today,
      eventDate: DateTime(2027, 8, 12),
      capabilities: {
        CapabilityDimension.aerobicEndurance: 62,
        CapabilityDimension.durability: 50,
        CapabilityDimension.threshold: 70,
      },
    );

    final block = planner.buildBlock(input);

    expect(block.phase, TrainingPhase.foundation);
    expect(
      block.primaryAdaptation,
      anyOf(
        CapabilityDimension.aerobicEndurance,
        CapabilityDimension.durability,
      ),
    );
    expect(block.primaryAdaptation, isNot(CapabilityDimension.threshold));
  });

  test('threshold gap becomes primary in Build twelve weeks out', () {
    final input = _input(
      today: today,
      eventDate: today.add(const Duration(days: 84)),
      capabilities: {
        CapabilityDimension.aerobicEndurance: 82,
        CapabilityDimension.durability: 80,
        CapabilityDimension.threshold: 42,
      },
    );

    final block = planner.buildBlock(input);

    expect(block.phase, TrainingPhase.build);
    expect(block.primaryAdaptation, CapabilityDimension.threshold);
    expect(block.reasonCodes, contains('PHASE_BUILD'));
  });

  test('poor durability outranks strong threshold for long event', () {
    final gaps = planner.analyseGaps(_input(
      today: today,
      eventDate: today.add(const Duration(days: 120)),
      capabilities: {
        CapabilityDimension.aerobicEndurance: 75,
        CapabilityDimension.durability: 35,
        CapabilityDimension.threshold: 92,
      },
    ));

    expect(gaps.first.dimension, CapabilityDimension.durability);
  });

  test('missing capability evidence reduces gap priority confidence', () {
    final gaps = planner.analyseGaps(_input(
      today: today,
      eventDate: today.add(const Duration(days: 120)),
      capabilities: const {},
    ));

    expect(gaps.every((gap) => gap.confidence == 0), isTrue);
  });

  test('Foundation eligibility is led by endurance rather than threshold', () {
    final input = _input(
      today: today,
      eventDate: today.add(const Duration(days: 330)),
      capabilities: {
        CapabilityDimension.aerobicEndurance: 55,
        CapabilityDimension.durability: 50,
        CapabilityDimension.threshold: 45,
      },
    );
    final block = planner.buildBlock(input);
    final eligible = const WorkoutFamilyEligibilityEngine().evaluate(
      block: block,
      demands: input.demands,
    );
    double weight(WorkoutFamily family) =>
        eligible.singleWhere((item) => item.family == family).weight;

    expect(block.phase, TrainingPhase.foundation);
    expect(
      weight(WorkoutFamily.endurance),
      greaterThan(weight(WorkoutFamily.threshold)),
    );
    expect(
      weight(WorkoutFamily.longEndurance),
      greaterThan(weight(WorkoutFamily.vo2Max)),
    );
  });

  test('only phase-appropriate families enter recovery transition pool', () {
    final input = StrategicPlanningInput(
      today: today,
      eventDate: today.add(const Duration(days: 30)),
      demands: _input(
        today: today,
        eventDate: today.add(const Duration(days: 30)),
        capabilities: const {},
      ).demands,
      capabilities: AthleteCapabilityProfile(capabilities: const {}),
      recoveryTransitionRequired: true,
    );
    final eligible = const WorkoutFamilyEligibilityEngine().evaluate(
      block: planner.buildBlock(input),
      demands: input.demands,
    );

    expect(
      eligible
          .singleWhere((item) => item.family == WorkoutFamily.anaerobic)
          .isEligible,
      isFalse,
    );
    expect(
      eligible
          .singleWhere((item) => item.family == WorkoutFamily.endurance)
          .isEligible,
      isTrue,
    );
  });
}

StrategicPlanningInput _input({
  required DateTime today,
  required DateTime eventDate,
  required Map<CapabilityDimension, double> capabilities,
}) {
  final now = DateTime(2026, 9, 12);
  final values = {
    for (final entry in capabilities.entries)
      entry.key: AthleteCapability(
        score: entry.value,
        confidence: .85,
        trend: CapabilityTrend.stable,
        evidenceCount: 8,
        lastUpdated: now,
      ),
  };
  return StrategicPlanningInput(
    today: today,
    eventDate: eventDate,
    demands: EventDemandProfile(demands: const {
      CapabilityDimension.aerobicEndurance: 95,
      CapabilityDimension.durability: 95,
      CapabilityDimension.tempo: 75,
      CapabilityDimension.threshold: 75,
      CapabilityDimension.vo2max: 55,
      CapabilityDimension.anaerobicCapacity: 20,
      CapabilityDimension.sprintPower: 10,
      CapabilityDimension.climbingEndurance: 75,
      CapabilityDimension.muscularEndurance: 85,
      CapabilityDimension.fatigueResistance: 90,
      CapabilityDimension.repeatability: 55,
    }),
    capabilities: AthleteCapabilityProfile(capabilities: values),
  );
}
