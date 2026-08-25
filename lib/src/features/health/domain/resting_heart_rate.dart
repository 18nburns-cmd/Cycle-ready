class TimedHeartRate {
  const TimedHeartRate(this.time, this.beatsPerMinute);
  final DateTime time;
  final double beatsPerMinute;
}

double? estimateRestingHeartRate(
  Iterable<TimedHeartRate> samples, {
  required DateTime now,
}) {
  final recent = samples
      .where((sample) =>
          sample.time.isAfter(now.subtract(const Duration(hours: 36))) &&
          sample.beatsPerMinute >= 30 &&
          sample.beatsPerMinute <= 220)
      .toList();
  if (recent.isEmpty) return null;

  final overnight = recent
      .where((sample) => sample.time.hour < 9 || sample.time.hour >= 22)
      .map((sample) => sample.beatsPerMinute)
      .toList();
  final values = overnight.length >= 3
      ? overnight
      : recent.map((sample) => sample.beatsPerMinute).toList();
  values.sort();

  // A low percentile is more representative of rest than the latest sample,
  // while avoiding a single sensor dropout or implausible minimum.
  final index = ((values.length - 1) * .2).round();
  return values[index];
}
