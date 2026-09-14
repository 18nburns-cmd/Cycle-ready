import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';

enum TrainingRecommendation {
  rest,
  recovery,
  easy,
  endurance,
  tempo,
  threshold,
  vo2,
  normalPlannedSession,
}

class RecommendationThresholds {
  const RecommendationThresholds({
    this.veryLowMax = 30,
    this.lowMax = 50,
    this.moderateMax = 70,
    this.goodMax = 85,
  });
  final int veryLowMax;
  final int lowMax;
  final int moderateMax;
  final int goodMax;
}

class DecisionEngine {
  const DecisionEngine({
    this.thresholds = const RecommendationThresholds(),
    this.policy = const AdaptiveTrainingPolicy(),
  });
  final RecommendationThresholds thresholds;
  final AdaptiveTrainingPolicy policy;

  AdaptiveTrainingPolicyDecision evaluatePolicy(
    AdaptiveTrainingPolicyInput input,
  ) =>
      policy.evaluate(input);

  TrainingRecommendation recommend({
    required int readiness,
    required double form,
    required int hardSessions7Days,
    required int recoveryHours,
  }) {
    if (readiness <= thresholds.veryLowMax || form < -25) {
      return TrainingRecommendation.rest;
    }
    if (readiness <= thresholds.lowMax || recoveryHours > 36) {
      return TrainingRecommendation.recovery;
    }
    if (readiness <= thresholds.moderateMax || hardSessions7Days >= 3) {
      return TrainingRecommendation.endurance;
    }
    if (readiness <= thresholds.goodMax) {
      return TrainingRecommendation.normalPlannedSession;
    }
    return hardSessions7Days >= 2
        ? TrainingRecommendation.tempo
        : TrainingRecommendation.threshold;
  }
}

typedef TrainingRecommendationEngine = DecisionEngine;
