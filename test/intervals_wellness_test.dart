import 'package:cycle_ready/src/features/intervals/domain/intervals_wellness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses latest resting HR and prior records as baseline', () {
    final result = summariseIntervalsHeartRate([
      IntervalsWellness(day: DateTime(2026, 7, 25), restingHeartRate: 50),
      IntervalsWellness(day: DateTime(2026, 7, 26), restingHeartRate: 52),
      IntervalsWellness(day: DateTime(2026, 7, 27), restingHeartRate: 55),
    ]);

    expect(result!.latest, 55);
    expect(result.baseline, 51);
    expect(result.sampleCount, 3);
  });

  test('falls back to average sleeping HR and rejects invalid values', () {
    final result = summariseIntervalsHeartRate([
      IntervalsWellness(day: DateTime(2026, 7, 26), restingHeartRate: 5),
      IntervalsWellness(
          day: DateTime(2026, 7, 27), averageSleepingHeartRate: 48),
    ]);

    expect(result!.latest, 48);
  });

  test('uses latest HRV rMSSD and prior values as personal baseline', () {
    final result = summariseIntervalsHrv([
      IntervalsWellness(day: DateTime(2026, 7, 25), hrvRmssd: 48),
      IntervalsWellness(day: DateTime(2026, 7, 26), hrvRmssd: 52),
      IntervalsWellness(day: DateTime(2026, 7, 27), hrvRmssd: 44),
    ]);
    expect(result!.latest, 44);
    expect(result.baseline, 50);
    expect(result.source, 'rMSSD');
  });

  test('falls back to SDNN only when rMSSD is unavailable', () {
    final result = summariseIntervalsHrv([
      IntervalsWellness(day: DateTime(2026, 7, 27), hrvSdnn: 61),
    ]);
    expect(result!.latest, 61);
    expect(result.source, 'SDNN');
  });
}
