import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/relational_coaching_data.dart';
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

  test('maps authoritative relational records without a snapshot', () {
    final relational = RelationalCoachingData(
      athlete: const {
        'current_ftp': 250,
        'maximum_hr': 190,
        'body_mass_kg': 75,
      },
      activities: const [
        {
          'id': 'activity-1',
          'started_at': '2026-08-30T08:00:00Z',
          'duration_seconds': 3600,
          'distance_metres': 32000,
          'elevation_metres': 300,
          'average_power': 205,
          'normalized_power': 220,
          'average_hr': 147,
          'average_cadence': 88,
          'training_load': 70,
          'source_payload': {'name': 'Threshold session'},
        }
      ],
      wellness: const [
        {
          'recorded_date': '2026-08-31',
          'sleep_minutes': 460,
          'hrv_ms': 55,
          'resting_hr': 51,
        }
      ],
      weights: const [
        {'measured_at': '2026-08-31T07:00:00Z', 'weight_kg': 74.5}
      ],
      plannedSessions: const [
        {
          'scheduled_date': '2026-09-01',
          'session_type': 'endurance',
          'purpose': 'Aerobic endurance',
          'planned_duration_minutes': 60,
          'planned_load': 45,
          'primary_adaptation': 'aerobic_endurance',
          'adaptation_status': 'KEEP',
        }
      ],
      ftpHistory: const [
        {
          'effective_date': '2026-08-01',
          'ftp': 250,
          'confidence': 0.9,
        }
      ],
      nutritionEntries: const [
        {
          'recorded_at': '2026-08-31T12:00:00Z',
          'label': 'Lunch',
          'calories': 550,
          'carbohydrate_grams': 75,
          'protein_grams': 28,
          'fat_grams': 16,
          'water_millilitres': 400,
        }
      ],
      nutritionTargets: const [
        {
          'target_date': '2026-08-31',
          'calories': 2400,
          'carbohydrate_grams': 300,
          'protein_grams': 140,
          'fat_grams': 70,
          'water_millilitres': 3000,
        }
      ],
      latestReadiness: const {'readiness_score': 76},
      latestDecision: AuthoritativeCoachingDecision.fromJson(const {
        'id': 'decision-1',
        'created_at': '2026-08-31T06:00:00Z',
        'decision': 'KEEP',
        'adaptation_level': 0,
        'reason_codes': ['PLANNED_SESSION_SUITABLE'],
        'explanation': 'The planned session remains suitable.',
        'confidence': 0.9,
        'original_workout': {'id': 'ENDURANCE_45'},
        'replacement_workout': {'id': 'ENDURANCE_45'},
        'coaching_model_version': 'adaptive-decision-v2.0.0',
      }),
      updatedAt: DateTime.utc(2026, 8, 31),
    );

    final portal = WebPortalData.fromRelational(relational);
    expect(portal.activities.single.title, 'Threshold session');
    expect(portal.activities.single.normalisedPower, 220);
    expect(portal.recovery.single.hrvMilliseconds, 55);
    expect(portal.planned.single.adaptationReason, 'KEEP');
    expect(portal.ftp, 250);
    expect(portal.currentWeight, 74.5);
    expect(portal.nutritionFor(DateTime(2026, 8, 31)).calories, 550);
  });
}
