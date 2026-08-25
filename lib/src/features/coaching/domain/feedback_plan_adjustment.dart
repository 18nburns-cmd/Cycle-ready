import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';

class FeedbackPlanAdjustment {
  const FeedbackPlanAdjustment({
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    required this.prescription,
  });

  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String prescription;
}

FeedbackPlanAdjustment? adjustPlanFromFeedback({
  required PostRideTrainingAdjustment adjustment,
  required SessionType existingType,
  required int ftp,
}) {
  if (adjustment == PostRideTrainingAdjustment.none ||
      existingType == SessionType.rest ||
      existingType == SessionType.recovery) {
    return null;
  }
  if (adjustment == PostRideTrainingAdjustment.recoveryOnly) {
    return FeedbackPlanAdjustment(
      type: SessionType.recovery,
      title: 'Recovery spin · adjusted from feedback',
      durationMinutes: 35,
      targetLoad: 15,
      prescription:
          'Below ${(ftp * .55).round()} W · discomfort reported after the previous ride',
    );
  }
  if (existingType == SessionType.tempo ||
      existingType == SessionType.intervals) {
    return FeedbackPlanAdjustment(
      type: SessionType.endurance,
      title: 'Aerobic endurance · adjusted from feedback',
      durationMinutes: 50,
      targetLoad: 32,
      prescription:
          '${(ftp * .58).round()}–${(ftp * .68).round()} W · intensity reduced after high effort or leg fatigue',
    );
  }
  return null;
}
