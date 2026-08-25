import 'package:cycle_ready/src/features/body/domain/body_metric.dart';

abstract interface class BodyMeasurementRepository {
  Stream<List<BodyMetric>> watchMeasurements();
  Future<void> saveMeasurement(BodyMetric measurement);
  Future<void> replaceHealthMeasurements(
    Iterable<BodyMetric> measurements, {
    required DateTime since,
  });
}
