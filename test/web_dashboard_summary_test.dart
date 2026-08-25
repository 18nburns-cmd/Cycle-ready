import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a cloud snapshot into web-safe headline metrics', () {
    final updatedAt = DateTime.utc(2026, 8, 25, 20, 30);
    final summary = WebDashboardSummary.fromSnapshot(
      CloudSnapshot(
        schemaVersion: 20,
        updatedAt: updatedAt,
        sourceDevice: 'Android',
        payload: {
          'activities': [
            {
              'distanceMetres': 40000.0,
              'durationSeconds': 3600,
              'trainingLoad': 65,
            },
            {
              'distanceMetres': 20000,
              'durationSeconds': 1800,
              'trainingLoad': null,
            },
          ],
          'athleteSettings': [
            {'ftp': 245},
          ],
          'bodyMeasurements': [
            {'measuredAt': '2026-08-24T07:00:00Z', 'weightKg': 74.3},
            {'measuredAt': '2026-08-25T07:00:00Z', 'weightKg': 73.9},
          ],
          'dailyRecovery': [
            {'day': '2026-08-25T00:00:00Z', 'hrvMilliseconds': 51.2},
          ],
        },
      ),
    );

    expect(summary.rideCount, 2);
    expect(summary.totalDistanceMetres, 60000);
    expect(summary.totalDurationSeconds, 5400);
    expect(summary.totalTrainingLoad, 65);
    expect(summary.ftp, 245);
    expect(summary.weightKg, 73.9);
    expect(summary.latestHrv, 51.2);
    expect(summary.updatedAt, updatedAt);
  });

  test('missing optional sections remain unknown rather than invented', () {
    final summary = WebDashboardSummary.fromSnapshot(
      CloudSnapshot(
        schemaVersion: 20,
        updatedAt: DateTime.utc(2026),
        sourceDevice: 'Android',
        payload: const {},
      ),
    );

    expect(summary.rideCount, 0);
    expect(summary.ftp, isNull);
    expect(summary.weightKg, isNull);
    expect(summary.latestHrv, isNull);
  });
}
