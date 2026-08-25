import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_activity_samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders and chunks samples without exceeding transport limit', () {
    final chunks = chunkActivitySamples(
      activityId: 'ride-1',
      chunkSize: 2,
      samples: const [
        CloudActivitySample(elapsedSeconds: 2, power: 220),
        CloudActivitySample(elapsedSeconds: 0, power: 180),
        CloudActivitySample(elapsedSeconds: 1, power: 200),
      ],
    );

    expect(chunks, hasLength(2));
    expect(chunks.first.samples.map((sample) => sample.elapsedSeconds), [0, 1]);
    expect(chunks.last.samples.single.elapsedSeconds, 2);
    expect(chunks.first.contentHash, hasLength(64));
  });

  test('sample JSON omits unavailable streams and round-trips coordinates', () {
    const sample = CloudActivitySample(
      elapsedSeconds: 14,
      heartRate: 145,
      latitude: 54.123,
      longitude: -2.456,
    );
    final json = sample.toJson();
    final restored = CloudActivitySample.fromJson(json);

    expect(json.containsKey('power'), isFalse);
    expect(restored.heartRate, 145);
    expect(restored.latitude, 54.123);
    expect(restored.longitude, -2.456);
  });
}
