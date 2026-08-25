import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/training_response.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingMetrics training({double form = 0, double ramp = 2}) => TrainingMetrics(
      fitness: 40,
      fatigue: 40 - form,
      form: form,
      weeklyLoad: 280,
      rampRate: ramp,
      history: const [],
    );

PerformanceMomentum momentum(PerformanceMomentumStatus status) =>
    PerformanceMomentum(
      status: status,
      headline: status.name,
      explanation: status.name,
      averageChangePercent: 3,
      comparisonCount: 3,
    );

void main() {
  test('fatigue safety overrides improving power', () {
    final result = assessTrainingResponse(
      training: training(form: -25),
      momentum: momentum(PerformanceMomentumStatus.improving),
    );
    expect(result.status, TrainingResponseStatus.fatigued);
  });

  test('improving power with controlled load is productive', () {
    final result = assessTrainingResponse(
      training: training(),
      momentum: momentum(PerformanceMomentumStatus.improving),
    );
    expect(result.status, TrainingResponseStatus.productive);
  });

  test('stable power is maintaining', () {
    final result = assessTrainingResponse(
      training: training(),
      momentum: momentum(PerformanceMomentumStatus.stable),
    );
    expect(result.status, TrainingResponseStatus.maintaining);
  });

  test('withholds judgement without comparable power', () {
    final result = assessTrainingResponse(training: training(), momentum: null);
    expect(result.status, TrainingResponseStatus.insufficientData);
  });

  test('mixed response with controlled load is rebuilding', () {
    final result = assessTrainingResponse(
      training: training(),
      momentum: momentum(PerformanceMomentumStatus.mixed),
    );
    expect(result.status, TrainingResponseStatus.rebuilding);
  });
}
