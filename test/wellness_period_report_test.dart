import 'package:cycle_ready/src/features/insights/domain/wellness_period_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly report totals rides and compares equivalent load', () {
    final result = buildWellnessPeriodReport(
      now: DateTime(2026, 8, 15),
      period: WellnessReportPeriod.month,
      rides: [
        WellnessReportRide(
            title: 'Tempo',
            startedAt: DateTime(2026, 8, 4),
            durationSeconds: 3600,
            distanceMetres: 30000,
            elevationMetres: 400,
            load: 70),
        WellnessReportRide(
            title: 'Endurance',
            startedAt: DateTime(2026, 7, 20),
            durationSeconds: 5400,
            distanceMetres: 45000,
            elevationMetres: 500,
            load: 50),
      ],
      recovery: const [],
      nutrition: const [],
      weights: const [],
    );
    expect(result.rideCount, 1);
    expect(result.load, 70);
    expect(result.previousLoad, 50);
    expect(result.bestRide!.title, 'Tempo');
  });

  test('warning requires HRV and resting HR to deteriorate together', () {
    final recovery = <WellnessReportRecovery>[
      for (var day = 1; day <= 3; day++)
        WellnessReportRecovery(
            day: DateTime(2026, 8, day), hrv: 40, restingHeartRate: 55),
      for (var day = 29; day <= 31; day++)
        WellnessReportRecovery(
            day: DateTime(2026, 7, day), hrv: 55, restingHeartRate: 49),
    ];
    final result = buildWellnessPeriodReport(
        now: DateTime(2026, 8, 15),
        period: WellnessReportPeriod.month,
        rides: const [],
        recovery: recovery,
        nutrition: const [],
        weights: const []);
    expect(result.warning, isNotNull);
  });

  test('12-week review compares equivalent blocks and coaching evidence', () {
    final now = DateTime(2026, 8, 25);
    final rides = <WellnessReportRide>[
      for (var week = 0; week < 12; week++)
        WellnessReportRide(
          title: 'Current endurance $week',
          startedAt: now.subtract(Duration(days: week * 7)),
          durationSeconds: 3600,
          distanceMetres: 30000,
          elevationMetres: 300,
          load: 100,
        ),
      for (var week = 12; week < 24; week++)
        WellnessReportRide(
          title: 'Previous endurance $week',
          startedAt: now.subtract(Duration(days: week * 7)),
          durationSeconds: 3600,
          distanceMetres: 30000,
          elevationMetres: 300,
          load: 70,
        ),
    ];
    final recovery = <WellnessReportRecovery>[
      for (var day = 0; day < 84; day++)
        WellnessReportRecovery(
          day: now.subtract(Duration(days: day)),
          hrv: 52,
          restingHeartRate: 49,
        ),
      for (var day = 84; day < 168; day++)
        WellnessReportRecovery(
          day: now.subtract(Duration(days: day)),
          hrv: 50,
          restingHeartRate: 50,
        ),
    ];

    final result = buildWellnessPeriodReport(
      now: now,
      period: WellnessReportPeriod.twelveWeeks,
      rides: rides,
      recovery: recovery,
      nutrition: const [],
      weights: const [],
    );

    expect(result.load, 1200);
    expect(result.previousLoad, 840);
    expect(result.activeWeeks, 12);
    expect(result.previousActiveWeeks, 12);
    expect(result.confidence, WellnessReviewConfidence.high);
    expect(result.coachingPriorities.first, contains('Consolidate'));
    expect(result.previousAverageHrv, 50);
  });

  test('12-week review lowers confidence when recovery data is missing', () {
    final result = buildWellnessPeriodReport(
      now: DateTime(2026, 8, 25),
      period: WellnessReportPeriod.twelveWeeks,
      rides: const [],
      recovery: const [],
      nutrition: const [],
      weights: const [],
    );

    expect(result.confidence, WellnessReviewConfidence.low);
    expect(result.coachingPriorities, contains(contains('recovery days')));
  });
}
