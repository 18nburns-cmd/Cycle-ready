import 'dart:math' as math;

enum FuelPriority { recovery, steady, demanding }

class NutritionPlan {
  const NutritionPlan({
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.calories,
    required this.hydrationMillilitres,
    required this.rideCarbsPerHour,
    required this.rideFluidPerHour,
    required this.preRideCarbs,
    required this.recoveryCarbs,
    required this.recoveryProtein,
    required this.priority,
    required this.explanation,
  });

  final int carbohydrateGrams;
  final int proteinGrams;
  final int fatGrams;
  final int calories;
  final int hydrationMillilitres;
  final int rideCarbsPerHour;
  final int rideFluidPerHour;
  final int preRideCarbs;
  final int recoveryCarbs;
  final int recoveryProtein;
  final FuelPriority priority;
  final String explanation;
}

class NutritionPlanner {
  const NutritionPlanner();

  NutritionPlan build({
    required double weightKg,
    required int rideMinutes,
    required int trainingLoad,
    required int readiness,
  }) {
    final safeWeight = weightKg.clamp(40, 160).toDouble();
    final durationHours = rideMinutes / 60;
    final priority = trainingLoad >= 60 || rideMinutes >= 90
        ? FuelPriority.demanding
        : trainingLoad >= 25 || rideMinutes >= 45
            ? FuelPriority.steady
            : FuelPriority.recovery;

    final carbFactor = switch (priority) {
      FuelPriority.recovery => 3.5,
      FuelPriority.steady => 5.0,
      FuelPriority.demanding => 6.5,
    };
    final proteinFactor = readiness < 50 ? 1.8 : 1.6;
    final rideCarbs = switch (priority) {
      FuelPriority.recovery => rideMinutes < 60 ? 0 : 30,
      FuelPriority.steady => 45,
      FuelPriority.demanding => durationHours >= 2.5 ? 75 : 60,
    };

    final carbs = (safeWeight * carbFactor).round();
    final protein = (safeWeight * proteinFactor).round();
    final fat = (safeWeight * .8).round();
    return NutritionPlan(
      carbohydrateGrams: carbs,
      proteinGrams: protein,
      fatGrams: fat,
      calories: carbs * 4 + protein * 4 + fat * 9,
      hydrationMillilitres: (safeWeight * 35).round(),
      rideCarbsPerHour: rideCarbs,
      rideFluidPerHour: priority == FuelPriority.demanding ? 650 : 500,
      preRideCarbs: rideMinutes < 45
          ? 0
          : (safeWeight * (durationHours >= 2 ? 1.5 : 1)).round(),
      recoveryCarbs: trainingLoad <= 0
          ? 0
          : (safeWeight * math.min(1.2, .6 + trainingLoad / 150)).round(),
      recoveryProtein: trainingLoad <= 0 ? 0 : (safeWeight * .3).round(),
      priority: priority,
      explanation: switch (priority) {
        FuelPriority.recovery =>
          'Completed training is currently light or none, so targets remain at the lighter-day level. They will increase automatically if more training syncs.',
        FuelPriority.steady =>
          'Today’s completed training is classified as steady. Targets have increased to support recovery from the work you actually did.',
        FuelPriority.demanding =>
          'Today’s completed training is classified as demanding. Carbohydrate and recovery targets have increased for the work you actually did.',
      },
    );
  }
}
