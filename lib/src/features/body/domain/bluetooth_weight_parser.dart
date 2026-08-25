class BluetoothWeightMeasurement {
  const BluetoothWeightMeasurement({
    required this.weightKg,
    this.bodyFatPercent,
  });

  final double weightKg;
  final double? bodyFatPercent;
}

/// Decodes the Bluetooth SIG Weight Measurement characteristic (0x2A9D).
///
/// Proprietary scale packets are intentionally not guessed here: an incorrect
/// byte order can produce a plausible but wrong health measurement.
BluetoothWeightMeasurement? parseStandardWeightMeasurement(List<int> bytes) {
  if (bytes.length < 3) return null;
  final flags = bytes[0];
  final imperial = flags & 0x01 != 0;
  final rawWeight = bytes[1] | (bytes[2] << 8);
  final weightKg = imperial ? rawWeight * 0.01 * 0.45359237 : rawWeight * 0.005;
  if (!weightKg.isFinite || weightKg < 20 || weightKg > 350) return null;
  return BluetoothWeightMeasurement(weightKg: weightKg);
}
