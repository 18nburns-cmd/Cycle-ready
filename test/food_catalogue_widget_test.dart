import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/nutrition/application/food_catalogue_controller.dart';
import 'package:cycle_ready/src/features/nutrition/data/open_food_facts_repository.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/food_catalogue_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets('selecting a catalogue serving adds populated nutrition',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = OpenFoodFactsRepository(
        client: MockClient((_) async => throw Exception('offline')));
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(database),
      foodCatalogueRepositoryProvider.overrideWithValue(repository)
    ], child: const MaterialApp(home: FoodCatalogueScreen())));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Scan barcode'), findsOneWidget);
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-serving-amount')), '2');
    await tester.tap(find.text('Add to today'));
    await tester.pumpAndSettle();
    final entries = await database.getNutritionEntries(DateTime.now());
    expect(entries, hasLength(1));
    expect(entries.single.label, 'Banana');
    expect(entries.single.calories, 210);
    expect(entries.single.carbohydrateGrams, 54);
  });
}
