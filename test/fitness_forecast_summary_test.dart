import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

FitnessPoint point(double fitness, double fatigue, {bool future = false}) =>
    FitnessPoint(
      date: DateTime(2026, 8, future ? 25 : 24),
      fitness: fitness,
      fatigue: fatigue,
      form: fitness - fatigue,
      load: 0,
      isForecast: future,
    );

void main() {
  test('labels a controlled fitness increase as productive', () {
    final summary = summariseFitnessForecast(
      current: point(50, 48),
      forecast: [point(51.2, 62, future: true)],
    );
    expect(summary?.status, ForecastLoadStatus.productive);
    expect(summary?.fitnessChange, closeTo(1.2, .01));
  });

  test('fatigue warning overrides a predicted fitness gain', () {
    final summary = summariseFitnessForecast(
      current: point(50, 48),
      forecast: [
        point(51, 74, future: true),
        point(52, 84, future: true),
      ],
    );
    expect(summary?.status, ForecastLoadStatus.excessive);
    expect(summary?.lowestForm, -32);
  });

  test('small change with manageable form is maintaining', () {
    final summary = summariseFitnessForecast(
      current: point(50, 48),
      forecast: [point(50.4, 55, future: true)],
    );
    expect(summary?.status, ForecastLoadStatus.maintaining);
  });
}
