import 'package:cycle_ready/src/features/nutrition/domain/recovery_nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demanding ride produces recovery targets from body mass', () {
    final result = calculateRecoveryNutrition(
      weightKg: 70,
      durationSeconds: 7200,
      trainingLoad: 100,
    );

    expect(result.carbohydrateGrams, 84);
    expect(result.proteinGrams, 21);
    expect(result.fluidMillilitres, 1000);
    expect(result.notificationBody, contains('84 g carbs'));
  });

  test('short easy ride still recommends a practical fluid minimum', () {
    final result = calculateRecoveryNutrition(
      weightKg: 70,
      durationSeconds: 1800,
      trainingLoad: 15,
    );

    expect(result.carbohydrateGrams, 35);
    expect(result.fluidMillilitres, 400);
  });
}
