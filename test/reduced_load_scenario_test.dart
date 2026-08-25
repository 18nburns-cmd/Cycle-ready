import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reduces the hardest day and improves predicted lowest form', () {
    final current = FitnessPoint(
      date: DateTime(2026, 8, 24),
      fitness: 50,
      fatigue: 48,
      form: 2,
      load: 0,
    );
    final original = projectFitnessForecast(
      history: [current],
      plannedLoads: [
        (date: DateTime(2026, 8, 25), load: 60.0),
        (date: DateTime(2026, 8, 27), load: 180.0),
        (date: DateTime(2026, 8, 30), load: 80.0),
      ],
      through: DateTime(2026, 9, 7),
    );
    final originalSummary = summariseFitnessForecast(
      current: current,
      forecast: original,
    )!;
    final scenario = buildReducedLoadScenario(
      current: current,
      forecast: original,
    )!;

    expect(scenario.day, DateTime(2026, 8, 27));
    expect(scenario.originalLoad, 180);
    expect(scenario.reducedLoad, closeTo(126, .001));
    expect(
        scenario.summary.lowestForm, greaterThan(originalSummary.lowestForm));
    expect(scenario.summary.endFitness, lessThan(originalSummary.endFitness));
  });

  test('does not invent a scenario when no training is planned', () {
    final current = FitnessPoint(
      date: DateTime(2026, 8, 24),
      fitness: 50,
      fatigue: 48,
      form: 2,
      load: 0,
    );
    final forecast = projectFitnessForecast(
      history: [current],
      plannedLoads: const [],
      through: DateTime(2026, 9, 7),
    );
    expect(
      buildReducedLoadScenario(current: current, forecast: forecast),
      isNull,
    );
  });
}
