import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_plan.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_progress.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';

final nutritionPlannerProvider = Provider((ref) => const NutritionPlanner());
final nutritionEntryControllerProvider = Provider(NutritionEntryController.new);
final savedFoodsProvider = StreamProvider<List<SavedFood>>(
  (ref) => ref.watch(databaseProvider).watchSavedFoods(),
);

final todayNutritionEntriesProvider = FutureProvider<List<NutritionEntry>>(
  (ref) => ref.watch(databaseProvider).getNutritionEntries(DateTime.now()),
);

final todayNutritionTargetProvider = FutureProvider<DailyNutritionTarget?>(
  (ref) => ref.watch(databaseProvider).getNutritionTarget(DateTime.now()),
);

final todayNutritionProvider = Provider<NutritionPlan>((ref) {
  final now = DateTime.now();
  final rides = ref.watch(activitiesProvider).valueOrNull ?? const [];
  final todayRides = rides.where((ride) =>
      ride.startedAt.year == now.year &&
      ride.startedAt.month == now.month &&
      ride.startedAt.day == now.day);
  final completedMinutes =
      todayRides.fold<int>(0, (sum, ride) => sum + ride.durationSeconds ~/ 60);
  final completedLoad =
      todayRides.fold<int>(0, (sum, ride) => sum + (ride.trainingLoad ?? 0));
  final settings = ref.watch(athleteSettingsProvider).valueOrNull;
  final strength = ref.watch(strengthWorkloadsProvider).valueOrNull ?? const [];
  final todayStrength = strength.where((workout) =>
      workout.completedAt.year == now.year &&
      workout.completedAt.month == now.month &&
      workout.completedAt.day == now.day);
  final strengthMinutes = todayStrength.fold<int>(
      0, (sum, workout) => sum + workout.durationMinutes);
  final strengthLoad =
      todayStrength.fold<double>(0, (sum, workout) => sum + workout.load);

  return ref.watch(nutritionPlannerProvider).build(
        weightKg: settings?.weightKg ?? 70,
        // Nutrition targets respond only to training that has actually been
        // completed. A planned or recommended session must not inflate today's
        // food target before the athlete rides.
        rideMinutes: completedMinutes + strengthMinutes,
        trainingLoad: completedLoad + strengthLoad.round(),
        readiness: ref.watch(todayReadinessProvider).score,
      );
});

final todayNutritionProgressProvider = Provider<NutritionProgress>((ref) {
  final plan = ref.watch(todayNutritionProvider);
  final savedTarget = ref.watch(todayNutritionTargetProvider).valueOrNull;
  final entries =
      ref.watch(todayNutritionEntriesProvider).valueOrNull ?? const [];
  final target = NutritionTotals(
    calories: savedTarget?.calories ?? plan.calories,
    carbohydrateGrams:
        (savedTarget?.carbohydrateGrams ?? plan.carbohydrateGrams).toDouble(),
    proteinGrams: (savedTarget?.proteinGrams ?? plan.proteinGrams).toDouble(),
    fatGrams: (savedTarget?.fatGrams ?? plan.fatGrams).toDouble(),
    waterMillilitres:
        savedTarget?.waterMillilitres ?? plan.hydrationMillilitres,
  );
  final consumed = NutritionTotals(
    calories: entries.fold(0, (sum, entry) => sum + entry.calories),
    carbohydrateGrams:
        entries.fold(0, (sum, entry) => sum + entry.carbohydrateGrams),
    proteinGrams: entries.fold(0, (sum, entry) => sum + entry.proteinGrams),
    fatGrams: entries.fold(0, (sum, entry) => sum + entry.fatGrams),
    waterMillilitres:
        entries.fold(0, (sum, entry) => sum + entry.waterMillilitres),
  );
  return NutritionProgress(target: target, consumed: consumed);
});

class NutritionEntryController {
  NutritionEntryController(this.ref);
  final Ref ref;

  Future<void> add({
    required String label,
    required int calories,
    required double carbohydrateGrams,
    required double proteinGrams,
    required double fatGrams,
    required int waterMillilitres,
    bool saveToLibrary = false,
  }) async {
    final cleanLabel = label.trim().isEmpty ? 'Food or drink' : label.trim();
    await ref.read(databaseProvider).saveNutritionEntry(
          NutritionEntriesCompanion.insert(
            recordedAt: DateTime.now(),
            label: Value(cleanLabel),
            calories: Value(calories.clamp(0, 5000)),
            carbohydrateGrams: Value(carbohydrateGrams.clamp(0, 1000)),
            proteinGrams: Value(proteinGrams.clamp(0, 500)),
            fatGrams: Value(fatGrams.clamp(0, 500)),
            waterMillilitres: Value(waterMillilitres.clamp(0, 10000)),
          ),
        );
    if (saveToLibrary) {
      await saveFood(
        name: cleanLabel,
        calories: calories,
        carbohydrateGrams: carbohydrateGrams,
        proteinGrams: proteinGrams,
        fatGrams: fatGrams,
        waterMillilitres: waterMillilitres,
      );
    }
    ref.invalidate(todayNutritionEntriesProvider);
  }

  Future<void> saveFood({
    required String name,
    required int calories,
    required double carbohydrateGrams,
    required double proteinGrams,
    required double fatGrams,
    required int waterMillilitres,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    await ref.read(databaseProvider).saveFood(
          SavedFoodsCompanion.insert(
            name: cleanName,
            calories: Value(calories.clamp(0, 5000)),
            carbohydrateGrams: Value(carbohydrateGrams.clamp(0, 1000)),
            proteinGrams: Value(proteinGrams.clamp(0, 500)),
            fatGrams: Value(fatGrams.clamp(0, 500)),
            waterMillilitres: Value(waterMillilitres.clamp(0, 10000)),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteFood(String name) =>
      ref.read(databaseProvider).deleteSavedFood(name);

  Future<void> updateFood({
    required String originalName,
    required String name,
    required int calories,
    required double carbohydrateGrams,
    required double proteinGrams,
    required double fatGrams,
    required int waterMillilitres,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    if (cleanName != originalName) {
      await ref.read(databaseProvider).deleteSavedFood(originalName);
    }
    await saveFood(
      name: cleanName,
      calories: calories,
      carbohydrateGrams: carbohydrateGrams,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      waterMillilitres: waterMillilitres,
    );
  }

  Future<void> updateEntry({
    required int id,
    required String label,
    required int calories,
    required double carbohydrateGrams,
    required double proteinGrams,
    required double fatGrams,
    required int waterMillilitres,
  }) async {
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return;
    await ref.read(databaseProvider).updateNutritionEntry(
          id,
          NutritionEntriesCompanion(
            label: Value(cleanLabel),
            calories: Value(calories.clamp(0, 5000)),
            carbohydrateGrams: Value(carbohydrateGrams.clamp(0, 1000)),
            proteinGrams: Value(proteinGrams.clamp(0, 500)),
            fatGrams: Value(fatGrams.clamp(0, 500)),
            waterMillilitres: Value(waterMillilitres.clamp(0, 10000)),
          ),
        );
    ref.invalidate(todayNutritionEntriesProvider);
  }

  Future<void> delete(int id) async {
    await ref.read(databaseProvider).deleteNutritionEntry(id);
    ref.invalidate(todayNutritionEntriesProvider);
  }

  Future<void> saveTarget(NutritionTotals target) async {
    final now = DateTime.now();
    await ref.read(databaseProvider).saveNutritionTarget(
          DailyNutritionTargetsCompanion.insert(
            day: DateTime(now.year, now.month, now.day),
            calories: target.calories,
            carbohydrateGrams: target.carbohydrateGrams.round(),
            proteinGrams: target.proteinGrams.round(),
            fatGrams: target.fatGrams.round(),
            waterMillilitres: target.waterMillilitres,
          ),
        );
    ref.invalidate(todayNutritionTargetProvider);
  }
}
