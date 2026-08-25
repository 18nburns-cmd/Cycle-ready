import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/coach_ai_report.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_debrief.dart';
import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ride = DebriefRide(
    id: 'ride',
    startedAt: DateTime(2026, 8, 1, 9),
    durationSeconds: 3600,
    trainingLoad: 72,
    averagePower: 190,
    averageHeartRate: 145,
  );

  test('coaches against a planned workout and returns a verdict', () {
    final report = buildCoachAiReport(
      ride: ride,
      history: const [],
      advanced: const AdvancedRideMetrics(
        bestEfforts: [],
        aerobicDecouplingPercent: 2.5,
        averageCadence: 88,
        powerCoveragePercent: 100,
        heartRateCoveragePercent: 100,
      ),
      analysis: const RideAnalysis(
        averageSpeedMph: 20,
        intensityFactor: .88,
        powerToWeight: 2.7,
        powerHeartRateRatio: 1.31,
        variabilityIndex: 1.05,
        workKilojoules: 684,
        powerZones: [],
        heartRateZones: [],
      ),
      ftp: 220,
      weightKg: 70,
      plannedType: 'tempo',
      plannedMinutes: 60,
      plannedLoad: 70,
    );

    expect(report.objective, contains('Tempo'));
    expect(report.executionScore, greaterThanOrEqualTo(8));
    expect(report.verdict.sessionQuality, 'Excellent');
    expect(report.recovery, contains('protein'));
  });

  test('never assumes normal heart rate when data is missing', () {
    final report = buildCoachAiReport(
      ride: DebriefRide(
        id: 'missing',
        startedAt: DateTime(2026, 8, 1),
        durationSeconds: 1800,
        trainingLoad: null,
        averagePower: null,
        averageHeartRate: null,
      ),
      history: const [],
      advanced: const AdvancedRideMetrics(
        bestEfforts: [],
        aerobicDecouplingPercent: null,
        averageCadence: null,
        powerCoveragePercent: 0,
        heartRateCoveragePercent: 0,
      ),
      analysis: const RideAnalysis(
        averageSpeedMph: 0,
        intensityFactor: null,
        powerToWeight: null,
        powerHeartRateRatio: null,
        variabilityIndex: null,
        workKilojoules: null,
        powerZones: [],
        heartRateZones: [],
      ),
      ftp: 220,
      weightKg: 70,
    );

    expect(report.heartRate, contains('unavailable'));
    expect(report.power, contains('not available'));
    expect(report.confidence, CoachConfidence.low);
  });

  test('discomfort overrides performance praise and requires rest', () {
    final report = buildCoachAiReport(
      ride: ride,
      history: const [],
      advanced: const AdvancedRideMetrics(
        bestEfforts: [],
        aerobicDecouplingPercent: 2,
        averageCadence: 90,
        powerCoveragePercent: 100,
        heartRateCoveragePercent: 100,
      ),
      analysis: const RideAnalysis(
        averageSpeedMph: 20,
        intensityFactor: .9,
        powerToWeight: 2.7,
        powerHeartRateRatio: 1.31,
        variabilityIndex: 1.04,
        workKilojoules: 684,
        powerZones: [],
        heartRateZones: [],
      ),
      ftp: 220,
      weightKg: 70,
      discomfort: 8,
    );

    expect(report.fatigue, contains('dominant signal'));
    expect(report.verdict.tomorrow, 'Complete rest');
    expect(report.verdict.recoveryDemand, 'Very high');
  });

  test('recognises workout objective from imported activity title', () {
    final titledRide = DebriefRide(
      id: 'tempo',
      title: 'Tempo 15s',
      startedAt: DateTime(2026, 8, 1),
      durationSeconds: 3600,
      trainingLoad: 65,
      averagePower: 185,
      averageHeartRate: 142,
    );
    final report = buildCoachAiReport(
      ride: titledRide,
      history: const [],
      advanced: const AdvancedRideMetrics(
        bestEfforts: [],
        aerobicDecouplingPercent: 3,
        averageCadence: 88,
        powerCoveragePercent: 100,
        heartRateCoveragePercent: 100,
      ),
      analysis: const RideAnalysis(
        averageSpeedMph: 19,
        intensityFactor: .82,
        powerToWeight: 2.6,
        powerHeartRateRatio: 1.3,
        variabilityIndex: 1.06,
        workKilojoules: 666,
        powerZones: [],
        heartRateZones: [],
      ),
      ftp: 225,
      weightKg: 70,
      enjoyment: 9,
    );
    expect(report.objective, contains('Tempo'));
    expect(report.objective, contains('Tempo 15s'));
    expect(report.doneWell, contains(contains('enjoyment')));
  });
}
