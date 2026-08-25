class PostRideFeedbackInput {
  const PostRideFeedbackInput({
    required this.perceivedEffort,
    required this.legFatigue,
    required this.enjoyment,
    required this.discomfort,
  });

  final int perceivedEffort;
  final int legFatigue;
  final int enjoyment;
  final int discomfort;
}

enum PostRideTrainingAdjustment { none, avoidIntensity, recoveryOnly }

PostRideTrainingAdjustment trainingAdjustmentFromFeedback(
  PostRideFeedbackInput feedback,
) {
  if (feedback.discomfort >= 7) {
    return PostRideTrainingAdjustment.recoveryOnly;
  }
  if (feedback.legFatigue >= 8 || feedback.perceivedEffort >= 9) {
    return PostRideTrainingAdjustment.avoidIntensity;
  }
  return PostRideTrainingAdjustment.none;
}

String interpretPostRideFeedback(PostRideFeedbackInput feedback) {
  if (feedback.discomfort >= 7) {
    return 'Significant discomfort recorded. Avoid forcing the next session and monitor how it settles.';
  }
  if (feedback.legFatigue >= 8 || feedback.perceivedEffort >= 9) {
    return 'That felt exceptionally demanding. Your next recommendation should favour recovery.';
  }
  if (feedback.perceivedEffort <= 4 && feedback.legFatigue <= 4) {
    return 'You absorbed this ride comfortably and finished with good reserves.';
  }
  if (feedback.enjoyment >= 8) {
    return 'A productive ride you enjoyed—useful information when shaping future training.';
  }
  return 'A solid, manageable session. CycleReady will retain this response with the ride.';
}
