import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planned calendar load projects fitness, fatigue and form', () {
    final today = DateTime(2026, 8, 24);
    final history = [
      FitnessPoint(
        date: today,
        fitness: 50,
        fatigue: 45,
        form: 5,
        load: 0,
      ),
    ];
    final forecast = projectFitnessForecast(
      history: history,
      plannedLoads: [
        (date: DateTime(2026, 8, 25), load: 100.0),
        (date: DateTime(2026, 8, 27), load: 80.0),
      ],
      through: DateTime(2026, 8, 31),
    );
    expect(forecast, hasLength(7));
    expect(forecast.first.isForecast, isTrue);
    expect(forecast.first.load, 100);
    expect(forecast.first.fitness, greaterThan(50));
    expect(forecast.first.fatigue, greaterThan(45));
    expect(forecast.first.form, lessThan(5));
  });

  test('rest days decay fatigue faster than fitness', () {
    final today = DateTime(2026, 8, 24);
    final forecast = projectFitnessForecast(
      history: [
        FitnessPoint(
          date: today,
          fitness: 50,
          fatigue: 80,
          form: -30,
          load: 0,
        ),
      ],
      plannedLoads: const [],
      through: DateTime(2026, 8, 31),
    );
    expect(forecast.last.fatigue, lessThan(forecast.last.fitness));
    expect(forecast.last.form, greaterThan(-30));
  });
}
