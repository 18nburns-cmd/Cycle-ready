import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/nutrition_screen.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adding intake refreshes safely after the sheet closes',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          recoveryControllerProvider.overrideWith(_FakeRecoveryController.new),
        ],
        child: const MaterialApp(home: NutritionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add intake'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test water');
    await tester.enterText(fields.at(2), '250');
    await tester.tap(find.text('Add to today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Intake added to today.'), findsOneWidget);
    final saved = await database.getNutritionEntries(DateTime.now());
    expect(saved, hasLength(1));
    expect(saved.single.label, 'Test water');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('recent intake can repopulate every nutrition field',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveNutritionEntry(
      NutritionEntriesCompanion.insert(
        recordedAt: DateTime.now().subtract(const Duration(days: 1)),
        label: const Value('Morning shake'),
        calories: const Value(320),
        carbohydrateGrams: const Value(28),
        proteinGrams: const Value(35),
        fatGrams: const Value(7),
        waterMillilitres: const Value(400),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          recoveryControllerProvider.overrideWith(_FakeRecoveryController.new),
        ],
        child: const MaterialApp(home: NutritionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add intake'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Morning shake'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text,
        'Morning shake');
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, '320');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, '400');
    expect(tester.widget<TextField>(fields.at(3)).controller!.text, '28');
    expect(tester.widget<TextField>(fields.at(4)).controller!.text, '35');
    expect(tester.widget<TextField>(fields.at(5)).controller!.text, '7');

    await tester.tap(find.text('Add to today'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final saved = await database.getNutritionEntries(DateTime.now());
    expect(saved, hasLength(1));
    expect(saved.single.label, 'Morning shake');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FakeRecoveryController extends RecoveryController {
  @override
  Future<RecoveryInput> build() async => RecoveryInput.defaults();
}
