import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metric activity values are formatted as imperial units', () {
    expect(Units.distance(1609.344), '1.0 mi');
    expect(Units.elevation(100), '328 ft');
  });
}
