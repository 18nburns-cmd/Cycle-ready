import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/coaching/domain/offline_coach.dart';
import 'package:cycle_ready/src/features/nutrition/application/nutrition_provider.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';

final offlineCoachEngineProvider =
    Provider((ref) => const OfflineCoachEngine());

final offlineCoachReportProvider = Provider<OfflineCoachReport>((ref) {
  final now = DateTime.now();
  final rides = ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
  final today = rides.where(
    (ride) =>
        ride.startedAt.year == now.year &&
        ride.startedAt.month == now.month &&
        ride.startedAt.day == now.day,
  );
  final strength = ref.watch(strengthWorkloadsProvider).valueOrNull ?? const [];
  final todayStrength = strength.where(
    (workout) =>
        workout.completedAt.year == now.year &&
        workout.completedAt.month == now.month &&
        workout.completedAt.day == now.day,
  );
  final strengthMinutes = todayStrength.fold<int>(
      0, (sum, workout) => sum + workout.durationMinutes);
  final strengthLoad =
      todayStrength.fold<double>(0, (sum, workout) => sum + workout.load);
  final powerProgress =
      ref.watch(powerCurveProgressProvider).valueOrNull ?? const [];
  return ref.watch(offlineCoachEngineProvider).build(
        readiness: ref.watch(todayReadinessProvider),
        recovery: ref.watch(recoveryControllerProvider).valueOrNull ??
            RecoveryInput.defaults(),
        training: ref.watch(fitnessMetricsProvider),
        nutrition: ref.watch(todayNutritionProgressProvider),
        rideCount: today.length,
        rideMinutes:
            today.fold(0, (sum, ride) => sum + ride.durationSeconds ~/ 60),
        completedLoad: today.fold<double>(
          strengthLoad,
          (sum, ride) => sum + (ride.trainingLoad?.toDouble() ?? 0),
        ),
        strengthSessionCount: todayStrength.length,
        strengthMinutes: strengthMinutes,
        performanceMomentum: assessPerformanceMomentum(powerProgress),
      );
});
