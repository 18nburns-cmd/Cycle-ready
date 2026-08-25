import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';

class MorningPlanChange {
  const MorningPlanChange({
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    required this.reason,
  });

  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String reason;
}

MorningPlanChange? adaptMorningWorkout({
  required SessionType existingType,
  required int readiness,
  required double form,
  required double rampRate,
}) {
  if (existingType == SessionType.rest ||
      existingType == SessionType.recovery) {
    return null;
  }
  if (readiness < 50 || form < -20 || rampRate > 10) {
    final reason = readiness < 50
        ? 'Readiness fell to $readiness, so today was changed to recovery.'
        : form < -20
            ? 'Training fatigue is high, so today was changed to recovery.'
            : 'Ramp rate is above the safe build range, so today was changed to recovery.';
    return MorningPlanChange(
      type: SessionType.recovery,
      title: 'Recovery spin · morning adjustment',
      durationMinutes: 35,
      targetLoad: 15,
      reason: reason,
    );
  }
  if (readiness < 67 &&
      (existingType == SessionType.tempo ||
          existingType == SessionType.intervals)) {
    return MorningPlanChange(
      type: SessionType.endurance,
      title: 'Aerobic endurance · morning adjustment',
      durationMinutes: 50,
      targetLoad: 32,
      reason:
          'Readiness is $readiness, so intensity was reduced while retaining useful aerobic training.',
    );
  }
  return null;
}
