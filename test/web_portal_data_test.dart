import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_portal_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the synced snapshot into complete web portal sections', () {
    final data = WebPortalData.fromSnapshot(CloudSnapshot(
      schemaVersion: 21,
      updatedAt: DateTime.utc(2026, 8, 25),
      sourceDevice: 'phone',
      payload: {
        'activities': [
          {
            'id': 'ride-1',
            'title': 'Tempo 3 x 10',
            'startedAt': '2026-08-25T08:00:00Z',
            'durationSeconds': 3600,
            'distanceMetres': 30000,
            'elevationMetres': 400,
            'averagePower': 190,
            'averageHeartRate': 145,
            'trainingLoad': 72,
          }
        ],
        'athleteSettings': [
          {'ftp': 220, 'weightKg': 68}
        ],
        'dailyRecovery': [
          {
            'day': '2026-08-25T00:00:00Z',
            'sleepMinutes': 450,
            'hrvMilliseconds': 74,
          }
        ],
        'bodyMeasurements': [
          {
            'measuredAt': '2026-08-25T07:00:00Z',
            'weightKg': 67.2,
          }
        ],
        'plannedSessions': [
          {
            'day': '2026-08-26T00:00:00Z',
            'title': 'Endurance 90',
            'sessionType': 'endurance',
            'durationMinutes': 90,
            'targetLoad': 55,
          }
        ],
        'nutritionEntries': [
          {
            'recordedAt': '2026-08-25T12:00:00Z',
            'label': 'Lunch',
            'calories': 600,
            'carbohydrateGrams': 80,
            'proteinGrams': 30,
            'fatGrams': 18,
            'waterMillilitres': 500,
          }
        ],
        'dailyNutritionTargets': [
          {
            'day': '2026-08-25T00:00:00Z',
            'calories': 2400,
            'carbohydrateGrams': 300,
            'proteinGrams': 140,
            'fatGrams': 70,
            'waterMillilitres': 3000,
          }
        ],
        'ftpEstimates': [
          {
            'estimatedAt': '2026-08-24T00:00:00Z',
            'watts': 218,
            'confidence': 'high',
          }
        ],
      },
    ));

    expect(data.activities.single.averagePower, 190);
    expect(data.recovery.single.hrvMilliseconds, 74);
    expect(data.currentWeight, 67.2);
    expect(data.powerToWeight, closeTo(3.274, 0.001));
    expect(data.planned.single.title, 'Endurance 90');
    expect(data.nutritionFor(DateTime(2026, 8, 25)).calories, 600);
    expect(data.ftpHistory.single.watts, 218);
  });
}
