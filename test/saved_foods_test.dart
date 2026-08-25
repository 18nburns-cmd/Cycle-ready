import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved foods remain separate and updating one does not remove another',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    Future<void> save(String name, int calories) => database.saveFood(
          SavedFoodsCompanion.insert(
            name: name,
            calories: Value(calories),
            updatedAt: DateTime(2026, 7, 30),
          ),
        );

    await save('Porridge', 300);
    await save('Recovery shake', 220);
    await save('Porridge', 325);

    final foods = await database.getSavedFoods();
    expect(foods, hasLength(2));
    expect(
      foods.singleWhere((food) => food.name == 'Porridge').calories,
      325,
    );
    expect(
      foods.singleWhere((food) => food.name == 'Recovery shake').calories,
      220,
    );
  });
}
