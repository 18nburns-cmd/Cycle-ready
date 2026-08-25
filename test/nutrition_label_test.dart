import 'package:cycle_ready/src/features/nutrition/domain/nutrition_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads common UK per 100g nutrition text', () {
    final label = parseNutritionLabel('''
      Typical values per 100g
      Energy 1046kJ / 250kcal
      Fat 8.0g
      Carbohydrate 30.0g
      Protein 12.0g
    ''');

    expect(label.referenceGrams, 100);
    expect(label.calories, 250);
    expect(label.fatGrams, 8);
    expect(label.carbohydrateGrams, 30);
    expect(label.proteinGrams, 12);
  });

  test('scales label values to amount eaten', () {
    const label = NutritionLabel(
      referenceGrams: 100,
      calories: 250,
      carbohydrateGrams: 30,
      proteinGrams: 12,
      fatGrams: 8,
    );

    final portion = label.scaledTo(160);
    expect(portion.calories, 400);
    expect(portion.carbohydrateGrams, 48);
    expect(portion.proteinGrams, closeTo(19.2, .001));
    expect(portion.fatGrams, closeTo(12.8, .001));
  });

  test('matches macro values split into separate OCR table columns', () {
    const fragments = [
      NutritionTextFragment(
          text: 'Fat', left: 10, top: 100, right: 70, bottom: 120),
      NutritionTextFragment(
          text: '8.0 g', left: 220, top: 101, right: 270, bottom: 121),
      NutritionTextFragment(
          text: 'of which saturates',
          left: 20,
          top: 130,
          right: 150,
          bottom: 150),
      NutritionTextFragment(
          text: '2.0 g', left: 220, top: 131, right: 270, bottom: 151),
      NutritionTextFragment(
          text: 'Carbohydrate', left: 10, top: 160, right: 150, bottom: 180),
      NutritionTextFragment(
          text: '30,0 g', left: 220, top: 161, right: 280, bottom: 181),
      NutritionTextFragment(
          text: 'Protein', left: 10, top: 220, right: 90, bottom: 240),
      NutritionTextFragment(
          text: '12.0 g', left: 220, top: 221, right: 280, bottom: 241),
    ];

    final label = parseNutritionLabel(
      'Energy 250 kcal\nFat\nof which saturates\nCarbohydrate\nProtein',
      fragments: fragments,
    );

    expect(label.fatGrams, 8);
    expect(label.carbohydrateGrams, 30);
    expect(label.proteinGrams, 12);
  });
}
