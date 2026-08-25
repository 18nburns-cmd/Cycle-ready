import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prioritises significant discomfort', () {
    final result = interpretPostRideFeedback(const PostRideFeedbackInput(
      perceivedEffort: 5,
      legFatigue: 5,
      enjoyment: 7,
      discomfort: 8,
    ));
    expect(result, contains('Significant discomfort'));
  });

  test('recognises a comfortably absorbed ride', () {
    final result = interpretPostRideFeedback(const PostRideFeedbackInput(
      perceivedEffort: 3,
      legFatigue: 4,
      enjoyment: 8,
      discomfort: 1,
    ));
    expect(result, contains('good reserves'));
  });

  test('significant discomfort requires a recovery day', () {
    final result = trainingAdjustmentFromFeedback(
      const PostRideFeedbackInput(
        perceivedEffort: 6,
        legFatigue: 6,
        enjoyment: 5,
        discomfort: 8,
      ),
    );
    expect(result, PostRideTrainingAdjustment.recoveryOnly);
  });

  test('exceptional fatigue protects the next day from intensity', () {
    final result = trainingAdjustmentFromFeedback(
      const PostRideFeedbackInput(
        perceivedEffort: 9,
        legFatigue: 8,
        enjoyment: 7,
        discomfort: 2,
      ),
    );
    expect(result, PostRideTrainingAdjustment.avoidIntensity);
  });
}
