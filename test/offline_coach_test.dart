import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/coaching/domain/offline_coach.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_progress.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = OfflineCoachEngine();

  test('completed ride produces a specific private coaching report', () {
    final report = engine.build(
      readiness: _readiness(75),
      recovery: RecoveryInput.defaults(),
      training: _metrics(form: -5),
      nutrition: _nutrition(protein: 110, water: 2200),
      rideCount: 1,
      rideMinutes: 90,
      completedLoad: 82,
    );

    expect(report.tone, CoachTone.celebrate);
    expect(report.wins.first, contains('90 minutes'));
    expect(report.wins.first, contains('82 load'));
    expect(report.tonight, isNotEmpty);
  });

  test('fatigue overrides motivational pressure to train', () {
    final report = engine.build(
      readiness: _readiness(72),
      recovery: RecoveryInput.defaults(),
      training: _metrics(form: -25),
      nutrition: _nutrition(protein: 40, water: 500),
      rideCount: 0,
      rideMinutes: 0,
      completedLoad: 0,
    );

    expect(report.tone, CoachTone.recover);
    expect(report.tomorrow, contains('rest day'));
    expect(report.focus, contains(contains('fatigue')));
  });

  test('a fresh day without training is not praised as completed work', () {
    final report = engine.build(
      readiness: _readiness(80),
      recovery: RecoveryInput.defaults(),
      training: _metrics(form: 5),
      nutrition: _nutrition(protein: 40, water: 500),
      rideCount: 0,
      rideMinutes: 0,
      completedLoad: 0,
    );

    expect(report.tone, CoachTone.steady);
    expect(report.message, contains('No workout is recorded today'));
    expect(report.message, isNot(contains('Good work today')));
  });
}

ReadinessResult _readiness(int score) => ReadinessResult(
      score: score,
      band: score >= 67 ? ReadinessBand.high : ReadinessBand.moderate,
      headline: 'Test',
      recommendation: 'Test',
      factors: const [],
    );

TrainingMetrics _metrics({required double form}) => TrainingMetrics(
      fitness: 50,
      fatigue: 50 - form,
      form: form,
      weeklyLoad: 300,
      rampRate: 2,
      history: const [],
    );

NutritionProgress _nutrition({
  required double protein,
  required int water,
}) =>
    NutritionProgress(
      target: const NutritionTotals(
        calories: 2400,
        carbohydrateGrams: 300,
        proteinGrams: 130,
        fatGrams: 70,
        waterMillilitres: 2500,
      ),
      consumed: NutritionTotals(
        calories: 2000,
        carbohydrateGrams: 240,
        proteinGrams: protein,
        fatGrams: 60,
        waterMillilitres: water,
      ),
    );
