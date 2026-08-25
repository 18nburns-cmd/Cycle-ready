import 'dart:math' as math;

class RecoveryNutritionRecommendation {
  const RecoveryNutritionRecommendation({
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fluidMillilitres,
  });

  final int carbohydrateGrams;
  final int proteinGrams;
  final int fluidMillilitres;

  String get notificationBody =>
      'Aim for $carbohydrateGrams g carbs, $proteinGrams g protein and about '
      '$fluidMillilitres ml fluid now.';
}

RecoveryNutritionRecommendation calculateRecoveryNutrition({
  required double weightKg,
  required int durationSeconds,
  required int trainingLoad,
}) {
  final safeWeight = weightKg.clamp(40, 160).toDouble();
  final minutes = durationSeconds / 60;
  final demanding = trainingLoad >= 80 || minutes >= 120;
  final steady = trainingLoad >= 35 || minutes >= 60;
  final carbohydrateFactor = demanding
      ? 1.2
      : steady
          ? .8
          : .5;
  final estimatedRideFluid = (minutes / 60 * (demanding ? 650 : 500)).round();
  return RecoveryNutritionRecommendation(
    carbohydrateGrams: (safeWeight * carbohydrateFactor).round(),
    proteinGrams: (safeWeight * .3).round(),
    fluidMillilitres: math.max(400, estimatedRideFluid.clamp(0, 1000)),
  );
}
