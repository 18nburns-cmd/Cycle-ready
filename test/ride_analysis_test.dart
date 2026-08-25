import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ride summary calculates imperial speed and intensity', () {
    final result = analyseRide(
      durationSeconds: 3600,
      distanceMetres: 32186.88,
      ftp: 250,
      maximumHeartRate: 190,
      weightKg: 70,
      averagePower: 210,
      normalisedPower: 225,
      samples: const [],
    );

    expect(result.averageSpeedMph, closeTo(20, .01));
    expect(result.intensityFactor, closeTo(.9, .001));
    expect(result.powerToWeight, 3);
  });

  test('sample time is assigned to power and heart-rate zones', () {
    final result = analyseRide(
      durationSeconds: 120,
      distanceMetres: 1000,
      ftp: 200,
      maximumHeartRate: 200,
      weightKg: 70,
      samples: const [
        (elapsedSeconds: 0, power: 100, heartRate: 110),
        (elapsedSeconds: 60, power: 200, heartRate: 180),
      ],
    );

    expect(result.powerZones[0].seconds, 60);
    expect(result.powerZones[3].seconds, 60);
    expect(result.heartRateZones[0].seconds, 60);
    expect(result.heartRateZones[4].seconds, 60);
  });

  test('personal best flags compare a ride with the full history', () {
    final flags = personalBestFlags(
      activityId: 'best',
      activities: const [
        (
          id: 'older',
          distance: 20000.0,
          elevation: 300.0,
          averagePower: 180,
          trainingLoad: 60,
        ),
        (
          id: 'best',
          distance: 40000.0,
          elevation: 800.0,
          averagePower: 220,
          trainingLoad: 100,
        ),
      ],
    );

    expect(flags.longestDistance, isTrue);
    expect(flags.highestElevation, isTrue);
    expect(flags.highestAveragePower, isTrue);
    expect(flags.highestTrainingLoad, isTrue);
  });
}
