import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/insights/domain/personal_insights.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final personalInsightsEngineProvider =
    Provider((ref) => const PersonalInsightsEngine());

final personalInsightsProvider = FutureProvider<PersonalInsightsReport>(
  (ref) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 55));
    final end =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final database = ref.watch(databaseProvider);
    final rides = await ref.watch(activitiesProvider.future);
    final settings = await ref.watch(athleteSettingsProvider.future);
    final recovery = await database.getRecoveryRecords(start, end);
    final entries = await database.getNutritionEntriesBetween(start, end);

    final carbsByDay = <DateTime, double>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.recordedAt.year,
        entry.recordedAt.month,
        entry.recordedAt.day,
      );
      carbsByDay.update(
        day,
        (value) => value + entry.carbohydrateGrams,
        ifAbsent: () => entry.carbohydrateGrams,
      );
    }

    return ref.watch(personalInsightsEngineProvider).build(
          now: now,
          rides: rides
              .where((ride) => !ride.startedAt.isBefore(start))
              .map((ride) {
            final estimated = estimateActivityLoad(
              durationSeconds: ride.durationSeconds,
              normalisedPower: ride.normalisedPower,
              averageHeartRate: ride.averageHeartRate,
              ftp: settings?.ftp ?? 200,
              restingHeartRate: settings?.restingHeartRate ?? 50,
              maximumHeartRate: settings?.maximumHeartRate ?? 190,
            );
            return InsightRide(
              startedAt: ride.startedAt,
              trainingLoad: ride.trainingLoad?.toDouble() ?? estimated.value,
              averagePower: ride.averagePower?.toDouble(),
              averageHeartRate: ride.averageHeartRate?.toDouble(),
            );
          }).toList(),
          recovery: recovery
              .map(
                (item) => InsightRecoveryDay(
                  day: item.day,
                  sleepMinutes: item.sleepMinutes,
                  restingHeartRate: item.restingHeartRate,
                ),
              )
              .toList(),
          nutrition: carbsByDay.entries
              .map(
                (item) => InsightNutritionDay(
                  day: item.key,
                  carbohydrateGrams: item.value,
                ),
              )
              .toList(),
        );
  },
);
