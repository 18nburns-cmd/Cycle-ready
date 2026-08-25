import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/feedback_plan_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discomfort converts a planned hard session to recovery', () {
    final result = adjustPlanFromFeedback(
      adjustment: PostRideTrainingAdjustment.recoveryOnly,
      existingType: SessionType.intervals,
      ftp: 240,
    );

    expect(result?.type, SessionType.recovery);
    expect(result?.targetLoad, 15);
    expect(result?.prescription, contains('132 W'));
  });

  test('high leg fatigue removes intensity but retains aerobic work', () {
    final result = adjustPlanFromFeedback(
      adjustment: PostRideTrainingAdjustment.avoidIntensity,
      existingType: SessionType.tempo,
      ftp: 250,
    );

    expect(result?.type, SessionType.endurance);
    expect(result?.prescription, contains('145–170 W'));
  });

  test('feedback never overwrites an existing rest day', () {
    final result = adjustPlanFromFeedback(
      adjustment: PostRideTrainingAdjustment.recoveryOnly,
      existingType: SessionType.rest,
      ftp: 250,
    );

    expect(result, isNull);
  });
}
