import 'package:cycle_ready/src/features/coaching/domain/training_recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = TrainingRecommendationEngine();

  test('safety rules prevent hard work on very low readiness', () {
    expect(
      engine.recommend(
        readiness: 25,
        form: 5,
        hardSessions7Days: 0,
        recoveryHours: 5,
      ),
      TrainingRecommendation.rest,
    );
  });

  test('high recovery time forces recovery despite moderate readiness', () {
    expect(
      engine.recommend(
        readiness: 65,
        form: 0,
        hardSessions7Days: 0,
        recoveryHours: 42,
      ),
      TrainingRecommendation.recovery,
    );
  });
}
