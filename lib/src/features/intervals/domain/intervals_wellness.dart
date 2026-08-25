class IntervalsWellness {
  const IntervalsWellness({
    required this.day,
    this.restingHeartRate,
    this.averageSleepingHeartRate,
    this.hrvRmssd,
    this.hrvSdnn,
  });

  final DateTime day;
  final double? restingHeartRate;
  final double? averageSleepingHeartRate;
  final double? hrvRmssd;
  final double? hrvSdnn;

  double? get preferredHeartRate =>
      restingHeartRate ?? averageSleepingHeartRate;
}

class IntervalsHrvSummary {
  const IntervalsHrvSummary(
      {required this.latest,
      required this.baseline,
      required this.sampleCount,
      required this.source});
  final double latest;
  final double baseline;
  final int sampleCount;
  final String source;
}

IntervalsHrvSummary? summariseIntervalsHrv(
    Iterable<IntervalsWellness> records) {
  final sorted = records.toList()..sort((a, b) => a.day.compareTo(b.day));
  var source = 'rMSSD';
  var valid = sorted
      .where(
          (e) => e.hrvRmssd != null && e.hrvRmssd! >= 5 && e.hrvRmssd! <= 250)
      .toList();
  if (valid.isEmpty) {
    source = 'SDNN';
    valid = sorted
        .where((e) => e.hrvSdnn != null && e.hrvSdnn! >= 5 && e.hrvSdnn! <= 300)
        .toList();
  }
  if (valid.isEmpty) return null;
  double value(IntervalsWellness item) =>
      source == 'rMSSD' ? item.hrvRmssd! : item.hrvSdnn!;
  final baselineRecords =
      valid.length > 1 ? valid.sublist(0, valid.length - 1) : valid;
  return IntervalsHrvSummary(
      latest: value(valid.last),
      baseline: baselineRecords.map(value).reduce((a, b) => a + b) /
          baselineRecords.length,
      sampleCount: valid.length,
      source: source);
}

class IntervalsHeartRateSummary {
  const IntervalsHeartRateSummary({
    required this.latest,
    required this.baseline,
    required this.sampleCount,
  });

  final double latest;
  final double baseline;
  final int sampleCount;
}

IntervalsHeartRateSummary? summariseIntervalsHeartRate(
    Iterable<IntervalsWellness> records) {
  final valid = records.where((record) {
    final value = record.preferredHeartRate;
    return value != null && value >= 30 && value <= 120;
  }).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  if (valid.isEmpty) return null;
  final baselineRecords =
      valid.length > 1 ? valid.sublist(0, valid.length - 1) : valid;
  final baseline = baselineRecords
          .map((record) => record.preferredHeartRate!)
          .reduce((a, b) => a + b) /
      baselineRecords.length;
  return IntervalsHeartRateSummary(
    latest: valid.last.preferredHeartRate!,
    baseline: baseline,
    sampleCount: valid.length,
  );
}
