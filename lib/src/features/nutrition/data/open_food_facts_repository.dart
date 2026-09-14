import 'dart:convert';

import 'package:cycle_ready/src/features/nutrition/data/bundled_food_catalogue.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_item.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_repository.dart';
import 'package:http/http.dart' as http;

class OpenFoodFactsRepository implements FoodCatalogueRepository {
  OpenFoodFactsRepository({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  static const _fields =
      'code,product_name,brands,serving_size,serving_quantity,serving_quantity_unit,nutriments';

  @override
  Future<List<FoodCatalogueItem>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    final local = bundledFoodCatalogue
        .where((item) => item.displayName.toLowerCase().contains(normalized))
        .toList();
    if (normalized.length < 2) return local;
    try {
      final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
        'search_terms': query.trim(),
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'fields': _fields,
      });
      final response = await _client.get(uri, headers: const {
        'User-Agent': 'CycleReady/1.0 (personal cycling coach)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return local;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = (body['products'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_product)
          .whereType<FoodCatalogueItem>();
      final seen = <String>{};
      return [...local, ...remote]
          .where((item) => seen.add(item.id))
          .take(30)
          .toList(growable: false);
    } catch (_) {
      return local;
    }
  }

  @override
  Future<FoodCatalogueItem?> findBarcode(String barcode) async {
    final clean = barcode.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 8) return null;
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/product/$clean.json',
        {'fields': _fields},
      );
      final response = await _client.get(uri, headers: const {
        'User-Agent': 'CycleReady/1.0 (personal cycling coach)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return _product(body['product'] as Map<String, dynamic>? ?? const {});
    } catch (_) {
      return null;
    }
  }

  FoodCatalogueItem? _product(Map<String, dynamic> product) {
    final name = (product['product_name'] as String?)?.trim() ?? '';
    final code = '${product['code'] ?? ''}'.trim();
    final nutrients = product['nutriments'] as Map<String, dynamic>?;
    if (name.isEmpty || code.isEmpty || nutrients == null) return null;
    double number(String key) =>
        (nutrients[key] as num?)?.toDouble() ?? double.nan;
    final calories100 = number('energy-kcal_100g');
    if (!calories100.isFinite) return null;
    final quantity = double.tryParse('${product['serving_quantity'] ?? ''}');
    final unit = '${product['serving_quantity_unit'] ?? ''}'.toLowerCase();
    final isVolume = unit == 'ml';
    final serving = quantity != null && quantity > 0 ? quantity : 100.0;
    final factor = serving / 100;
    double nutrient(String key) {
      final value = number('${key}_100g');
      return value.isFinite ? value * factor : 0;
    }

    return FoodCatalogueItem(
      id: 'off:$code',
      barcode: code,
      name: name,
      brand: (product['brands'] as String?)?.trim(),
      kind: isVolume ? FoodCatalogueKind.drink : FoodCatalogueKind.food,
      servingAmount: serving,
      servingUnit: isVolume ? 'ml' : 'g',
      calories: calories100 * factor,
      carbohydrateGrams: nutrient('carbohydrates'),
      proteinGrams: nutrient('proteins'),
      fatGrams: nutrient('fat'),
      waterMillilitres: isVolume ? serving : 0,
      source: 'Open Food Facts',
    );
  }
}
