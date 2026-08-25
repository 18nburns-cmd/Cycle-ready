import 'package:cycle_ready/src/features/readiness/domain/readiness_calculator.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final readinessCalculatorProvider =
    Provider((ref) => const ReadinessCalculator());

final todayReadinessProvider = Provider<ReadinessResult>((ref) {
  final input = ref.watch(recoveryControllerProvider).valueOrNull ??
      RecoveryInput.defaults();
  final load = ref.watch(fitnessMetricsProvider).weeklyLoad;
  return ref.watch(readinessCalculatorProvider).calculate(
        input.copyWith(recentTrainingLoad: load),
      );
});
