import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/body/data/drift_body_measurement_repository.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftBodyMeasurementRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftBodyMeasurementRepository(database);
  });

  tearDown(() => database.close());

  test('maps stored body measurements to domain metrics in date order',
      () async {
    await repository.saveMeasurement(
      BodyMetric(
        measuredAt: DateTime(2026, 8, 25),
        weightKg: 72.4,
        bodyFatPercent: 18.2,
        source: 'manual',
      ),
    );
    await repository.saveMeasurement(
      BodyMetric(
        measuredAt: DateTime(2026, 8, 24),
        weightKg: 72.7,
        source: 'bluetooth:RENPHO',
      ),
    );

    final values = await repository.watchMeasurements().first;
    expect(values.map((value) => value.weightKg), [72.7, 72.4]);
    expect(values.last.bodyFatPercent, 18.2);
    expect(values.first.source, 'bluetooth:RENPHO');
  });

  test('health replacement preserves manual history and older health data',
      () async {
    final cutoff = DateTime(2026, 8, 1);
    for (final value in [
      BodyMetric(
        measuredAt: DateTime(2026, 7, 20),
        weightKg: 73,
        source: 'healthConnect:RENPHO',
      ),
      BodyMetric(
        measuredAt: DateTime(2026, 8, 10),
        weightKg: 72.5,
        source: 'healthConnect:RENPHO',
      ),
      BodyMetric(
        measuredAt: DateTime(2026, 8, 12),
        weightKg: 72.3,
        source: 'manual',
      ),
    ]) {
      await repository.saveMeasurement(value);
    }

    await repository.replaceHealthMeasurements(
      [
        BodyMetric(
          measuredAt: DateTime(2026, 8, 15),
          weightKg: 72.1,
          source: 'healthConnect:Samsung Health',
        ),
      ],
      since: cutoff,
    );

    final values = await repository.watchMeasurements().first;
    expect(values, hasLength(3));
    expect(values.any((value) => value.weightKg == 73), isTrue);
    expect(values.any((value) => value.source == 'manual'), isTrue);
    expect(values.any((value) => value.weightKg == 72.5), isFalse);
    expect(values.any((value) => value.weightKg == 72.1), isTrue);
  });
}
