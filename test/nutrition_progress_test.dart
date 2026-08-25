import 'package:cycle_ready/src/features/nutrition/domain/nutrition_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consumed values subtract from each original target', () {
    const progress = NutritionProgress(
      target: NutritionTotals(
        calories: 2500,
        carbohydrateGrams: 300,
        proteinGrams: 140,
        fatGrams: 75,
        waterMillilitres: 2500,
      ),
      consumed: NutritionTotals(
        calories: 900,
        carbohydrateGrams: 110,
        proteinGrams: 50,
        fatGrams: 25,
        waterMillilitres: 750,
      ),
    );

    expect(progress.caloriesRemaining, 1600);
    expect(progress.carbohydrateRemaining, 190);
    expect(progress.proteinRemaining, 90);
    expect(progress.fatRemaining, 50);
    expect(progress.waterRemaining, 1750);
  });

  test('remaining values can show that a target was exceeded', () {
    const progress = NutritionProgress(
      target: NutritionTotals(calories: 2000, proteinGrams: 120),
      consumed: NutritionTotals(calories: 2200, proteinGrams: 130),
    );
    expect(progress.caloriesRemaining, -200);
    expect(progress.proteinRemaining, -10);
    expect(progress.fraction(2200, 2000), 1);
  });
}
