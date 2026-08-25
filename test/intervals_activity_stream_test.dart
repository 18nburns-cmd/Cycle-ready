import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identifies an Intervals Strava placeholder with unavailable data', () {
    expect(
      isRestrictedIntervalsActivity({
        'id': '19598528832',
        'source': 'STRAVA',
        'start_date_local': '2026-08-04T14:43:58',
        '_note': 'STRAVA activities are not available via the API',
      }),
      isTrue,
    );
  });

  test('does not mark a normal ride as restricted', () {
    expect(
      isRestrictedIntervalsActivity({
        'source': 'GARMIN',
        'type': 'Ride',
        'moving_time': 3600,
      }),
      isFalse,
    );
  });

  test('combines Intervals power, heart rate and GPS streams by time', () {
    final samples = parseIntervalsActivityStreams([
      {
        'type': 'time',
        'data': [0, 1, 2]
      },
      {
        'type': 'watts',
        'data': [180, 210, 230]
      },
      {
        'type': 'heartrate',
        'data': [120, 123, 126]
      },
      {
        'type': 'latlng',
        'data': [52.1, 52.2, 52.3],
        'data2': [-1.1, -1.2, -1.3],
      },
    ]);

    expect(samples, hasLength(3));
    expect(samples[1].elapsedSeconds, 1);
    expect(samples[1].watts, 210);
    expect(samples[1].heartRate, 123);
    expect(samples[1].latitude, 52.2);
    expect(samples[1].longitude, -1.2);
  });

  test('keeps available streams when others are absent', () {
    final samples = parseIntervalsActivityStreams([
      {
        'type': 'time',
        'data': [4]
      },
      {
        'type': 'cadence',
        'data': [88]
      },
    ]);
    expect(samples.single.elapsedSeconds, 4);
    expect(samples.single.cadence, 88);
    expect(samples.single.watts, isNull);
  });
}
