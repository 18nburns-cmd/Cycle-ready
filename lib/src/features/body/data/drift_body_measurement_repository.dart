import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/body/domain/body_measurement_repository.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriftBodyMeasurementRepository implements BodyMeasurementRepository {
  const DriftBodyMeasurementRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<BodyMetric>> watchMeasurements() => database
      .watchBodyMeasurements()
      .map((rows) => rows.map(_toDomain).toList(growable: false));

  @override
  Future<void> saveMeasurement(BodyMetric measurement) =>
      database.saveBodyMeasurement(_toCompanion(measurement));

  @override
  Future<void> replaceHealthMeasurements(
    Iterable<BodyMetric> measurements, {
    required DateTime since,
  }) =>
      database.replaceRecentHealthBodyMeasurements(
        measurements.map(_toCompanion),
        since: since,
      );

  BodyMetric _toDomain(BodyMeasurement row) => BodyMetric(
        measuredAt: row.measuredAt,
        weightKg: row.weightKg,
        bodyFatPercent: row.bodyFatPercent,
        source: row.source,
      );

  BodyMeasurementsCompanion _toCompanion(BodyMetric value) =>
      BodyMeasurementsCompanion.insert(
        measuredAt: value.measuredAt,
        weightKg: value.weightKg,
        bodyFatPercent: Value(value.bodyFatPercent),
        source: value.source,
      );
}

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>(
  (ref) => DriftBodyMeasurementRepository(ref.watch(databaseProvider)),
);
