import 'package:cycle_ready/src/features/activities/domain/ride_duplicate_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RideDuplicateCandidate ride({
    required String id,
    required DateTime start,
    String source = 'intervals_icu',
    int duration = 3600,
    double distance = 30000,
    int? power = 200,
  }) =>
      RideDuplicateCandidate(
        id: id,
        source: source,
        startedAt: start,
        durationSeconds: duration,
        distanceMetres: distance,
        averagePower: power,
      );

  test('flags close rides when independent details agree', () {
    final start = DateTime(2026, 9, 9, 8);
    final result = assessPossibleDuplicateRide(
      ride(id: 'health', start: start, source: 'health_connect'),
      ride(
        id: 'intervals',
        start: start.add(const Duration(minutes: 2)),
        duration: 3580,
        distance: 29900,
        power: 202,
      ),
    );

    expect(result.likelihood, RideDuplicateLikelihood.possible);
    expect(result.confidence, .95);
    expect(result.reasons,
        contains('The records came from different import sources.'));
  });

  test('does not flag rides based on timing alone', () {
    final start = DateTime(2026, 9, 9, 8);
    final result = assessPossibleDuplicateRide(
      ride(id: 'one', start: start, distance: 0, power: null),
      ride(
        id: 'two',
        start: start.add(const Duration(minutes: 1)),
        distance: 0,
        power: null,
      ),
    );

    expect(result.likelihood, RideDuplicateLikelihood.distinct);
  });

  test('scan returns each possible pair once and ignores distant rides', () {
    final start = DateTime(2026, 9, 9, 8);
    final results = findPossibleDuplicateRides([
      ride(id: 'one', start: start, source: 'health_connect'),
      ride(id: 'two', start: start.add(const Duration(minutes: 1))),
      ride(id: 'three', start: start.add(const Duration(hours: 2))),
    ]);

    expect(results, hasLength(1));
    expect({results.single.first.id, results.single.second.id}, {'one', 'two'});
  });
}
