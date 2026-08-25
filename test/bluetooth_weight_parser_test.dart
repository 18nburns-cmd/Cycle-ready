import 'package:cycle_ready/src/features/body/domain/bluetooth_weight_parser.dart';
import 'package:cycle_ready/src/features/body/data/bluetooth_scale_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats proprietary Bluetooth packets for diagnostics', () {
    expect(formatBluetoothPacket([0, 10, 171, 255]), '00 0A AB FF');
  });

  test('decodes a standard metric weight measurement', () {
    // 72.50 kg / 0.005 = 14500 = 0x38A4.
    final result = parseStandardWeightMeasurement([0, 0xA4, 0x38]);
    expect(result?.weightKg, closeTo(72.5, 0.001));
  });

  test('decodes a standard imperial weight measurement', () {
    // 160.00 lb / 0.01 = 16000 = 0x3E80.
    final result = parseStandardWeightMeasurement([1, 0x80, 0x3E]);
    expect(result?.weightKg, closeTo(72.5748, 0.001));
  });

  test('rejects incomplete and implausible packets', () {
    expect(parseStandardWeightMeasurement([0, 1]), isNull);
    expect(parseStandardWeightMeasurement([0, 1, 0]), isNull);
  });
}
