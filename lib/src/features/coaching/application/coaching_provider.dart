import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/domain/power_development_focus.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coachingEngineProvider = Provider((ref) => const DailyCoachingEngine());

final todayCoachingProvider = Provider<CoachingResult>((ref) {
  final recovery = ref.watch(recoveryControllerProvider).valueOrNull ??
      RecoveryInput.defaults();
  final athlete = ref.watch(athleteSettingsProvider).valueOrNull;
  final curve = ref.watch(powerCurveProvider).valueOrNull ?? const [];
  return ref.watch(coachingEngineProvider).build(
        now: DateTime.now(),
        readiness: ref.watch(todayReadinessProvider),
        recovery: recovery,
        metrics: ref.watch(fitnessMetricsProvider),
        developmentFocus: identifyPowerDevelopmentFocus(
          curve: curve,
          ftp: athlete?.ftp ?? 200,
        ),
      );
});
