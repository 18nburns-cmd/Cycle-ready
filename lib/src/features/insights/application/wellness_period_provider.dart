import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/body/application/body_measurement_controller.dart';
import 'package:cycle_ready/src/features/insights/domain/wellness_period_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final wellnessPeriodReportProvider =
    FutureProvider.family<WellnessPeriodReport, WellnessReportPeriod>(
        (ref, period) async {
  final now = DateTime.now();
  final yearStart = DateTime(now.year - 1, 1, 1);
  final end =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final database = ref.watch(databaseProvider);
  final rides = await ref.watch(activitiesProvider.future);
  final athlete = await ref.watch(athleteSettingsProvider.future);
  final recovery = await database.getRecoveryRecords(yearStart, end);
  final entries = await database.getNutritionEntriesBetween(yearStart, end);
  final bodies = await ref.watch(bodyMeasurementsProvider.future);
  final nutritionByDay = <DateTime, WellnessReportNutrition>{};
  for (final e in entries) {
    final day =
        DateTime(e.recordedAt.year, e.recordedAt.month, e.recordedAt.day);
    final old = nutritionByDay[day];
    nutritionByDay[day] = WellnessReportNutrition(
        day: day,
        calories: (old?.calories ?? 0) + e.calories,
        protein: (old?.protein ?? 0) + e.proteinGrams,
        carbohydrate: (old?.carbohydrate ?? 0) + e.carbohydrateGrams,
        water: (old?.water ?? 0) + e.waterMillilitres);
  }
  return buildWellnessPeriodReport(
      now: now,
      period: period,
      rides: rides
          .map((r) => WellnessReportRide(
              title: r.title,
              startedAt: r.startedAt,
              durationSeconds: r.durationSeconds,
              distanceMetres: r.distanceMetres,
              elevationMetres: r.elevationMetres,
              load: r.trainingLoad?.toDouble() ??
                  estimateActivityLoad(
                          durationSeconds: r.durationSeconds,
                          normalisedPower: r.normalisedPower,
                          averageHeartRate: r.averageHeartRate,
                          ftp: athlete?.ftp ?? 200,
                          restingHeartRate: athlete?.restingHeartRate ?? 50,
                          maximumHeartRate: athlete?.maximumHeartRate ?? 190)
                      .value))
          .toList(),
      recovery: recovery
          .map((r) => WellnessReportRecovery(
              day: r.day,
              sleepMinutes: r.sleepMinutes,
              hrv: r.hrvMilliseconds,
              restingHeartRate: r.restingHeartRate))
          .toList(),
      nutrition: nutritionByDay.values.toList(),
      weights: bodies.map((b) => (at: b.measuredAt, kg: b.weightKg)).toList());
});
