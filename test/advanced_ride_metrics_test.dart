import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds best rolling power efforts', () {
    final samples = List.generate(
      70,
      (second) => (
        elapsedSeconds: second,
        power: second >= 10 && second < 15 ? 500 : 200,
        heartRate: 140,
        cadence: 90,
      ),
    );
    final result = calculateAdvancedRideMetrics(
      durationSeconds: 70,
      samples: samples,
    );
    expect(
      result.bestEfforts.firstWhere((effort) => effort.seconds == 5).watts,
      500,
    );
    expect(result.averageCadence, 90);
    expect(result.powerCoveragePercent, 100);
  });

  test('calculates positive second-half aerobic drift', () {
    final samples = List.generate(
      2400,
      (second) => (
        elapsedSeconds: second,
        power: 200,
        heartRate: second < 1200 ? 140 : 154,
        cadence: 88,
      ),
    );
    final result = calculateAdvancedRideMetrics(
      durationSeconds: 2400,
      samples: samples,
    );
    expect(result.aerobicDecouplingPercent, closeTo(9.09, .1));
    expect(result.decouplingSummary, contains('drifted'));
  });

  test('requires adequate paired coverage for decoupling', () {
    final result = calculateAdvancedRideMetrics(
      durationSeconds: 2400,
      samples: const [
        (elapsedSeconds: 0, power: 200, heartRate: 140, cadence: 80),
      ],
    );
    expect(result.aerobicDecouplingPercent, isNull);
  });

  test('counts sustained high-power matches and measures pacing fade', () {
    final result = calculateAdvancedRideMetrics(
      durationSeconds: 1200,
      ftp: 250,
      samples: List.generate(
          1200,
          (second) => (
                elapsedSeconds: second,
                power: second >= 100 && second < 115
                    ? 350
                    : second >= 400 && second < 412
                        ? 330
                        : second < 600
                            ? 200
                            : 180,
                heartRate: 140,
                cadence: 88,
              )),
    );
    expect(result.matchesBurned, 2);
    expect(result.matchWorkKilojoules, greaterThan(2));
    expect(result.secondHalfPowerChangePercent, lessThan(0));
    expect(
        result.moments,
        contains(
            predicate<RideMoment>((m) => m.title == 'Largest match burned')));
  });
}
