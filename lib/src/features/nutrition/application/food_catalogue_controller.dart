import 'package:cycle_ready/src/features/nutrition/data/open_food_facts_repository.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_item.dart';
import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final foodCatalogueRepositoryProvider = Provider<FoodCatalogueRepository>(
  (_) => OpenFoodFactsRepository(),
);

final foodCatalogueSearchProvider = FutureProvider.autoDispose
    .family<List<FoodCatalogueItem>, String>((ref, query) {
  return ref.watch(foodCatalogueRepositoryProvider).search(query);
});
