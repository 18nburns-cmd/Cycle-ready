import 'package:cycle_ready/src/features/coaching/domain/planned_activity_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlannedMatchCandidate plan({
    String title = 'Tempo 3 x 12 min',
    DateTime? day,
    String type = 'tempo',
    int minutes = 60,
    int load = 70,
  }) =>
      PlannedMatchCandidate(
        id: title,
        day: day ?? DateTime(2026, 8, 25),
        sessionType: type,
        title: title,
        durationMinutes: minutes,
        targetLoad: load,
      );

  CompletedRideCandidate ride({
    String title = 'Tempo 3 x 12 min',
    DateTime? at,
    int minutes = 62,
    int? load = 72,
  }) =>
      CompletedRideCandidate(
        id: 'ride-1',
        startedAt: at ?? DateTime(2026, 8, 25, 18),
        title: title,
        durationMinutes: minutes,
        trainingLoad: load,
      );

  test('matches the planned workout on date, name, duration and load', () {
    final match = matchPlannedActivity(planned: [plan()], ride: ride());
    expect(match?.planned.title, 'Tempo 3 x 12 min');
    expect(match!.confidence, greaterThan(.8));
  });

  test('chooses the closest workout shape when several plans are nearby', () {
    final match = matchPlannedActivity(
      planned: [
        plan(title: 'Endurance 120', minutes: 120, load: 85),
        plan(),
      ],
      ride: ride(),
    );
    expect(match?.planned.title, 'Tempo 3 x 12 min');
  });

  test('matches an adjacent-date import only with supporting name evidence',
      () {
    final match = matchPlannedActivity(
      planned: [plan()],
      ride: ride(at: DateTime(2026, 8, 26, 0, 10)),
    );
    expect(match, isNotNull);

    final unrelated = matchPlannedActivity(
      planned: [plan()],
      ride: ride(
        title: 'Evening commute',
        at: DateTime(2026, 8, 26, 0, 10),
      ),
    );
    expect(unrelated, isNull);
  });

  test('never matches a rest day or a ride more than one date away', () {
    expect(
      matchPlannedActivity(
        planned: [plan(type: 'rest', minutes: 0, load: 0)],
        ride: ride(),
      ),
      isNull,
    );
    expect(
      matchPlannedActivity(
        planned: [plan()],
        ride: ride(at: DateTime(2026, 8, 27)),
      ),
      isNull,
    );
  });
}
