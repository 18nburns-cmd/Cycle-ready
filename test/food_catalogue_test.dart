import 'dart:convert';

import 'package:cycle_ready/src/features/nutrition/data/open_food_facts_repository.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('scales every nutrient to the selected serving', () {
    const item = FoodCatalogueItem(
        id: 'banana',
        name: 'Banana',
        kind: FoodCatalogueKind.food,
        servingAmount: 1,
        servingUnit: 'medium',
        calories: 105,
        carbohydrateGrams: 27,
        proteinGrams: 1.3,
        fatGrams: .4,
        waterMillilitres: 90);
    final doubled = item.scale(2);
    expect(doubled.servingAmount, 2);
    expect(doubled.calories, 210);
    expect(doubled.carbohydrateGrams, 54);
    expect(doubled.waterMillilitres, 180);
  });

  test('search combines offline basics with validated branded products',
      () async {
    final repository = OpenFoodFactsRepository(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'products': [
                {
                  'code': '12345678',
                  'product_name': 'Banana drink',
                  'brands': 'Test Brand',
                  'serving_quantity': '250',
                  'serving_quantity_unit': 'ml',
                  'nutriments': {
                    'energy-kcal_100g': 40,
                    'carbohydrates_100g': 9,
                    'proteins_100g': .5,
                    'fat_100g': .2
                  }
                }
              ]
            }),
            200)));
    final results = await repository.search('banana');
    expect(results.any((item) => item.id == 'banana'), isTrue);
    final drink = results.firstWhere((item) => item.id == 'off:12345678');
    expect(drink.calories, 100);
    expect(drink.carbohydrateGrams, 22.5);
    expect(drink.waterMillilitres, 250);
  });

  test('network failure preserves offline catalogue results', () async {
    final repository = OpenFoodFactsRepository(
        client: MockClient((_) async => throw Exception('offline')));
    final results = await repository.search('porridge');
    expect(results.single.name, 'Porridge oats');
  });

  test('barcode lookup returns a scaled UK packaged product', () async {
    final repository = OpenFoodFactsRepository(
      client: MockClient((request) async {
        expect(
            request.url.path, contains('/api/v2/product/5012345678900.json'));
        return http.Response(
          jsonEncode({
            'product': {
              'code': '5012345678900',
              'product_name': 'Recovery drink',
              'brands': 'UK Test',
              'serving_quantity': '500',
              'serving_quantity_unit': 'ml',
              'nutriments': {
                'energy-kcal_100g': 24,
                'carbohydrates_100g': 6,
                'proteins_100g': 0,
                'fat_100g': 0,
              },
            }
          }),
          200,
        );
      }),
    );

    final product = await repository.findBarcode('5012345678900');
    expect(product?.displayName, 'Recovery drink â€” UK Test');
    expect(product?.calories, 120);
    expect(product?.waterMillilitres, 500);
  });

  test('invalid barcode is rejected without a network request', () async {
    var requested = false;
    final repository = OpenFoodFactsRepository(
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    expect(await repository.findBarcode('not a barcode'), isNull);
    expect(requested, isFalse);
  });
}
