class NutritionTotals {
  const NutritionTotals({
    this.calories = 0,
    this.carbohydrateGrams = 0,
    this.proteinGrams = 0,
    this.fatGrams = 0,
    this.waterMillilitres = 0,
  });

  final int calories;
  final double carbohydrateGrams;
  final double proteinGrams;
  final double fatGrams;
  final int waterMillilitres;
}

class NutritionProgress {
  const NutritionProgress({
    required this.target,
    required this.consumed,
  });

  final NutritionTotals target;
  final NutritionTotals consumed;

  int get caloriesRemaining => target.calories - consumed.calories;
  double get carbohydrateRemaining =>
      target.carbohydrateGrams - consumed.carbohydrateGrams;
  double get proteinRemaining => target.proteinGrams - consumed.proteinGrams;
  double get fatRemaining => target.fatGrams - consumed.fatGrams;
  int get waterRemaining => target.waterMillilitres - consumed.waterMillilitres;

  double fraction(double consumedValue, double targetValue) =>
      targetValue <= 0 ? 0 : (consumedValue / targetValue).clamp(0, 1);
}
