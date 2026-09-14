import 'dart:async';

import 'package:cycle_ready/src/features/nutrition/application/food_catalogue_controller.dart';
import 'package:cycle_ready/src/features/nutrition/application/nutrition_provider.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_item.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/food_barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FoodCatalogueScreen extends ConsumerStatefulWidget {
  const FoodCatalogueScreen({super.key});

  @override
  ConsumerState<FoodCatalogueScreen> createState() =>
      _FoodCatalogueScreenState();
}

class _FoodCatalogueScreenState extends ConsumerState<FoodCatalogueScreen> {
  String query = '';
  Timer? debounce;

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(foodCatalogueSearchProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food & drink database'),
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('food-catalogue-search'),
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search food or drink',
              hintText: 'Banana, porridge, sports drinkâ€¦',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 350), () {
                if (mounted) setState(() => query = value);
              });
            },
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('Food search is unavailable. Try again shortly.'),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.trim().length < 2
                            ? 'Type at least two letters to search common and branded foods.'
                            : 'No matching item was found. You can still use the manual entry form.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(item.kind == FoodCatalogueKind.drink
                            ? Icons.local_drink_outlined
                            : Icons.restaurant_outlined),
                        title: Text(item.displayName),
                        subtitle: Text(
                          '${_amount(item.servingAmount)} ${item.servingUnit} Â· ${item.calories.round()} kcal Â· ${item.carbohydrateGrams.toStringAsFixed(1)} g carbs Â· ${item.proteinGrams.toStringAsFixed(1)} g protein',
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => _add(item),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _add(FoodCatalogueItem item) async {
    final amount = TextEditingController(text: _amount(item.servingAmount));
    var favourite = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item.displayName),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('food-serving-amount'),
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: 'Amount (${item.servingUnit})'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: favourite,
              onChanged: (value) =>
                  setDialogState(() => favourite = value ?? false),
              title: const Text('Save as a favourite'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add to today')),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final requested = double.tryParse(amount.text) ?? item.servingAmount;
    final scaled = item.scale(requested / item.servingAmount);
    await ref.read(nutritionEntryControllerProvider).add(
          label: scaled.displayName,
          calories: scaled.calories.round(),
          carbohydrateGrams: scaled.carbohydrateGrams,
          proteinGrams: scaled.proteinGrams,
          fatGrams: scaled.fatGrams,
          waterMillilitres: scaled.waterMillilitres.round(),
          saveToLibrary: favourite,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${scaled.displayName} added to today.')),
    );
  }

  Future<void> _scanBarcode() async {
    final product = await Navigator.push<FoodCatalogueItem>(
      context,
      MaterialPageRoute(builder: (_) => const FoodBarcodeScannerScreen()),
    );
    if (product != null && mounted) await _add(product);
  }
}

String _amount(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
