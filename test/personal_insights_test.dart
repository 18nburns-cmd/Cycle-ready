import 'package:cycle_ready/src/features/insights/domain/personal_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = PersonalInsightsEngine();
  final now = DateTime(2026, 7, 29);

  test('compares rolling four-week training blocks', () {
    final rides = <InsightRide>[
      for (var day = 49; day >= 28; day -= 7)
        InsightRide(
          startedAt: now.subtract(Duration(days: day)),
          trainingLoad: 50,
        ),
      for (var day = 21; day >= 0; day -= 7)
        InsightRide(
          startedAt: now.subtract(Duration(days: day)),
          trainingLoad: 75,
        ),
    ];

    final report = engine.build(
      now: now,
      rides: rides,
      recovery: const [],
      nutrition: const [],
    );

    expect(report.previousFourWeekLoad, 200);
    expect(report.currentFourWeekLoad, 300);
    expect(report.headline, 'Training momentum is building');
    expect(
      report.insights.firstWhere((item) => item.kind == 'load').message,
      contains('50%'),
    );
  });

  test('detects matched sleep and efficiency relationship', () {
    final rides = <InsightRide>[];
    final recovery = <InsightRecoveryDay>[];
    for (var index = 0; index < 12; index++) {
      final day = now.subtract(Duration(days: index * 3));
      final sleepHours = 6 + index * .15;
      recovery.add(
        InsightRecoveryDay(
          day: day,
          sleepMinutes: (sleepHours * 60).round(),
          restingHeartRate: 52,
        ),
      );
      rides.add(
        InsightRide(
          startedAt: day,
          trainingLoad: 60,
          averagePower: 150 + index * 5,
          averageHeartRate: 140,
        ),
      );
    }

    final report = engine.build(
      now: now,
      rides: rides,
      recovery: recovery,
      nutrition: const [],
    );
    final sleep = report.insights.firstWhere((item) => item.kind == 'sleep');

    expect(sleep.message, contains('Longer sleep'));
    expect(sleep.confidence, InsightConfidence.high);
    expect(sleep.sampleSize, 12);
  });

  test('does not invent correlation insights without matched data', () {
    final report = engine.build(
      now: now,
      rides: [
        InsightRide(startedAt: now, trainingLoad: 40),
      ],
      recovery: const [],
      nutrition: const [],
    );

    expect(report.insights.any((item) => item.kind == 'sleep'), isFalse);
    expect(report.insights.any((item) => item.kind == 'nutrition'), isFalse);
    expect(report.priorities, hasLength(3));
  });
}
