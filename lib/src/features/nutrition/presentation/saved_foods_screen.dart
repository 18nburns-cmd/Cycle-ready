import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/nutrition/application/nutrition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedFoodsScreen extends ConsumerWidget {
  const SavedFoodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(savedFoodsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Food & Drink Library')),
      body: foods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Library unavailable: $error')),
        data: (values) => values.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Your library is empty. Save an item while adding it, or scan a named food label.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: values.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _SavedFoodCard(food: values[index]),
              ),
      ),
    );
  }
}

class _SavedFoodCard extends ConsumerWidget {
  const _SavedFoodCard({required this.food});
  final SavedFood food;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(child: Icon(Icons.restaurant_menu)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(food.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Edit food',
                onPressed: () => _editSavedFood(context, ref, food),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remove from library',
                onPressed: () => ref
                    .read(nutritionEntryControllerProvider)
                    .deleteFood(food.name),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            const SizedBox(height: 8),
            Text(_summary(food)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await ref.read(nutritionEntryControllerProvider).add(
                        label: food.name,
                        calories: food.calories,
                        carbohydrateGrams: food.carbohydrateGrams,
                        proteinGrams: food.proteinGrams,
                        fatGrams: food.fatGrams,
                        waterMillilitres: food.waterMillilitres,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${food.name} added to today.')),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add this serving to today'),
              ),
            ),
          ]),
        ),
      );
}

Future<void> _editSavedFood(
  BuildContext context,
  WidgetRef ref,
  SavedFood food,
) async {
  final name = TextEditingController(text: food.name);
  final calories = TextEditingController(text: '${food.calories}');
  final carbs = TextEditingController(text: food.carbohydrateGrams.toString());
  final protein = TextEditingController(text: food.proteinGrams.toString());
  final fat = TextEditingController(text: food.fatGrams.toString());
  final water = TextEditingController(text: '${food.waterMillilitres}');
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Edit saved food'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: 'Food name',
                errorText: error,
              ),
            ),
            const SizedBox(height: 10),
            _editRow(calories, 'Calories', 'kcal', water, 'Water', 'ml'),
            const SizedBox(height: 10),
            _editRow(carbs, 'Carbs', 'g', protein, 'Protein', 'g'),
            const SizedBox(height: 10),
            _editRow(fat, 'Fat', 'g', null, '', ''),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) {
                setState(() => error = 'A name is required');
                return;
              }
              FocusScope.of(context).unfocus();
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    await ref.read(nutritionEntryControllerProvider).updateFood(
          originalName: food.name,
          name: name.text,
          calories: int.tryParse(calories.text) ?? 0,
          carbohydrateGrams: double.tryParse(carbs.text) ?? 0,
          proteinGrams: double.tryParse(protein.text) ?? 0,
          fatGrams: double.tryParse(fat.text) ?? 0,
          waterMillilitres: int.tryParse(water.text) ?? 0,
        );
  }
  await Future<void>.delayed(const Duration(milliseconds: 350));
  for (final controller in [name, calories, carbs, protein, fat, water]) {
    controller.dispose();
  }
}

Widget _editRow(
  TextEditingController first,
  String firstLabel,
  String firstSuffix,
  TextEditingController? second,
  String secondLabel,
  String secondSuffix,
) =>
    Row(children: [
      Expanded(child: _editField(first, firstLabel, firstSuffix)),
      if (second != null) ...[
        const SizedBox(width: 8),
        Expanded(child: _editField(second, secondLabel, secondSuffix)),
      ],
    ]);

Widget _editField(
  TextEditingController controller,
  String label,
  String suffix,
) =>
    TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );

String _summary(SavedFood food) {
  final parts = <String>[
    if (food.calories > 0) '${food.calories} kcal',
    if (food.carbohydrateGrams > 0)
      '${food.carbohydrateGrams.toStringAsFixed(1)} g carbs',
    if (food.proteinGrams > 0)
      '${food.proteinGrams.toStringAsFixed(1)} g protein',
    if (food.fatGrams > 0) '${food.fatGrams.toStringAsFixed(1)} g fat',
    if (food.waterMillilitres > 0) '${food.waterMillilitres} ml water',
  ];
  return parts.isEmpty ? 'No nutrition values saved' : parts.join(' • ');
}
