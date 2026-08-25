class BodyMetric {
  const BodyMetric({
    required this.measuredAt,
    required this.weightKg,
    required this.source,
    this.bodyFatPercent,
  });

  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
  final String source;
}
