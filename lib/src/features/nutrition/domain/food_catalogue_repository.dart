import 'package:cycle_ready/src/features/nutrition/domain/food_catalogue_item.dart';

abstract interface class FoodCatalogueRepository {
  Future<List<FoodCatalogueItem>> search(String query);
  Future<FoodCatalogueItem?> findBarcode(String barcode);
}
