enum FoodCatalogueKind { food, drink }

class FoodCatalogueItem {
  const FoodCatalogueItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.servingAmount,
    required this.servingUnit,
    required this.calories,
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.waterMillilitres,
    this.brand,
    this.barcode,
    this.source = 'CycleReady',
  });

  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final FoodCatalogueKind kind;
  final double servingAmount;
  final String servingUnit;
  final double calories;
  final double carbohydrateGrams;
  final double proteinGrams;
  final double fatGrams;
  final double waterMillilitres;
  final String source;

  String get displayName =>
      brand == null || brand!.isEmpty ? name : '$name â€” $brand';

  FoodCatalogueItem scale(double multiplier) {
    final safe = multiplier.clamp(.01, 100);
    return FoodCatalogueItem(
      id: id,
      name: name,
      brand: brand,
      barcode: barcode,
      kind: kind,
      servingAmount: servingAmount * safe,
      servingUnit: servingUnit,
      calories: calories * safe,
      carbohydrateGrams: carbohydrateGrams * safe,
      proteinGrams: proteinGrams * safe,
      fatGrams: fatGrams * safe,
      waterMillilitres: waterMillilitres * safe,
      source: source,
    );
  }
}
