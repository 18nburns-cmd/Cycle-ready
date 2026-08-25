import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/body/data/drift_body_measurement_repository.dart';
import 'package:cycle_ready/src/features/body/domain/body_csv_parser.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bodyMeasurementsProvider = StreamProvider<List<BodyMetric>>(
  (ref) => ref.watch(bodyMeasurementRepositoryProvider).watchMeasurements(),
);

final bodyMeasurementControllerProvider =
    Provider(BodyMeasurementController.new);

class BodyMeasurementController {
  BodyMeasurementController(this.ref);
  final Ref ref;

  Future<void> saveManual({
    required double weightKg,
    double? bodyFatPercent,
  }) =>
      _save(
        measuredAt: DateTime.now(),
        weightKg: weightKg,
        bodyFatPercent: bodyFatPercent,
        source: 'manual',
      );

  Future<void> saveBluetooth({
    required double weightKg,
    double? bodyFatPercent,
    String source = 'bluetooth:Hubit',
  }) =>
      _save(
        measuredAt: DateTime.now(),
        weightKg: weightKg,
        bodyFatPercent: bodyFatPercent,
        source: source,
      );

  Future<int> importCsv() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Body measurement CSV', extensions: ['csv'])
      ],
    );
    if (file == null) return 0;
    final parsed = parseBodyMeasurementsCsv(await file.readAsString());
    for (final value in parsed) {
      await _save(
        measuredAt: value.measuredAt,
        weightKg: value.weightKg,
        bodyFatPercent: value.bodyFatPercent,
        source: 'csv',
      );
    }
    return parsed.length;
  }

  Future<void> _save({
    required DateTime measuredAt,
    required double weightKg,
    required double? bodyFatPercent,
    required String source,
  }) async {
    await ref
        .read(bodyMeasurementRepositoryProvider)
        .saveMeasurement(BodyMetric(
          measuredAt: measuredAt,
          weightKg: weightKg,
          bodyFatPercent: bodyFatPercent,
          source: source,
        ));
    final athleteController = ref.read(athleteProfileControllerProvider);
    final profile = await athleteController.load();
    await athleteController.save(profile.copyWith(weightKg: weightKg));
  }
}
