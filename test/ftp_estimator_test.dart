import 'package:cycle_ready/src/features/activities/domain/ftp_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 27);

  test('uses a complete power-duration profile instead of only 20 minutes', () {
    const powers = [360, 330, 310, 290, 270, 260, 250, 240];
    final rides = List.generate(
      ftpDurations.length,
      (index) => PowerRide(
        date: now.subtract(Duration(days: index * 3)),
        durationSeconds: ftpDurations[index],
        samples: [PowerSample(0, powers[index])],
      ),
    );

    final result = estimateFtp(rides, now: now);

    expect(result, isNotNull);
    expect(result!.durationCoverage, 8);
    expect(result.rideCount, 8);
    expect(result.confidence, FtpConfidence.high);
    expect(result.watts, inInclusiveRange(240, 285));
    expect(result.lowWatts, lessThan(result.watts));
    expect(result.highWatts, greaterThan(result.watts));
  });

  test('excludes power data older than eight weeks', () {
    final result = estimateFtp(
      [
        PowerRide(
          date: now.subtract(const Duration(days: 70)),
          durationSeconds: 3600,
          samples: const [PowerSample(0, 300)],
        ),
      ],
      now: now,
    );

    expect(result, isNull);
  });

  test('requires more than one duration before estimating FTP', () {
    final result = estimateFtp(
      [
        PowerRide(
          date: now,
          durationSeconds: 180,
          samples: const [PowerSample(0, 350)],
        ),
      ],
      now: now,
    );

    expect(result, isNull);
  });
}
