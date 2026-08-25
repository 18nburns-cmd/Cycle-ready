import 'package:cycle_ready/src/features/activities/domain/post_ride_debrief.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares load and efficiency with the previous eight weeks', () {
    final now = DateTime(2026, 7, 29);
    final result = buildPostRideDebrief(
      ride: DebriefRide(
        id: 'current',
        startedAt: now,
        durationSeconds: 5400,
        trainingLoad: 100,
        averagePower: 210,
        averageHeartRate: 140,
      ),
      history: [
        DebriefRide(
          id: 'old',
          startedAt: now.subtract(const Duration(days: 7)),
          durationSeconds: 4000,
          trainingLoad: 50,
          averagePower: 180,
          averageHeartRate: 144,
        ),
      ],
      weightKg: 70,
    );

    expect(result.loadLabel, 'Demanding ride');
    expect(result.loadComparison, contains('100% above'));
    expect(result.efficiencyComparison, contains('20.0% more'));
    expect(result.comparisonRideCount, 1);
    expect(result.fuellingAction, contains('21 g protein'));
  });

  test('gives a useful fallback before a baseline exists', () {
    final result = buildPostRideDebrief(
      ride: DebriefRide(
        id: 'first',
        startedAt: DateTime(2026, 7, 29),
        durationSeconds: 1800,
        trainingLoad: null,
        averagePower: null,
        averageHeartRate: null,
      ),
      history: const [],
      weightKg: 70,
    );

    expect(result.loadLabel, 'Load unavailable');
    expect(result.efficiencyComparison, contains('unlock'));
    expect(result.comparisonRideCount, 0);
  });
}
