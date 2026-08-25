import 'package:cycle_ready/src/features/nutrition/domain/nutrition_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = NutritionPlanner();

  test('demanding long ride receives high during-ride fuel target', () {
    final plan = planner.build(
      weightKg: 70,
      rideMinutes: 180,
      trainingLoad: 140,
      readiness: 80,
    );

    expect(plan.priority, FuelPriority.demanding);
    expect(plan.rideCarbsPerHour, 75);
    expect(plan.recoveryProtein, 21);
    expect(plan.carbohydrateGrams, 455);
  });

  test('rest day does not invent workout nutrition', () {
    final plan = planner.build(
      weightKg: 70,
      rideMinutes: 0,
      trainingLoad: 0,
      readiness: 40,
    );

    expect(plan.priority, FuelPriority.recovery);
    expect(plan.rideCarbsPerHour, 0);
    expect(plan.preRideCarbs, 0);
    expect(plan.recoveryCarbs, 0);
    expect(plan.proteinGrams, 126);
  });

  test('short easy activity keeps lighter-day targets', () {
    final plan = const NutritionPlanner().build(
      weightKg: 70,
      rideMinutes: 30,
      trainingLoad: 18,
      readiness: 70,
    );

    expect(plan.priority, FuelPriority.recovery);
    expect(plan.carbohydrateGrams, 245);
  });

  test('completed moderate activity promotes day to steady', () {
    final plan = const NutritionPlanner().build(
      weightKg: 70,
      rideMinutes: 60,
      trainingLoad: 40,
      readiness: 70,
    );

    expect(plan.priority, FuelPriority.steady);
    expect(plan.carbohydrateGrams, 350);
  });

  test('unrealistic body weights are bounded safely', () {
    final plan = planner.build(
      weightKg: 10,
      rideMinutes: 60,
      trainingLoad: 40,
      readiness: 70,
    );

    expect(plan.carbohydrateGrams, 200);
    expect(plan.hydrationMillilitres, 1400);
  });
}
