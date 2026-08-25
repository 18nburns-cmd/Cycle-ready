import 'package:cycle_ready/src/features/body/domain/body_csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses common AFit-style metric columns', () {
    final values = parseBodyMeasurementsCsv(
      'Date,Weight (kg),Body Fat %\n'
      '26/07/2026,71.4,18.2\n'
      '27/07/2026,71.1,18.0\n',
    );

    expect(values, hasLength(2));
    expect(values.last.weightKg, 71.1);
    expect(values.last.bodyFatPercent, 18);
  });

  test('converts pounds when the header identifies lb', () {
    final values = parseBodyMeasurementsCsv(
      'datetime,weight lb\n2026-07-27,154.324\n',
    );

    expect(values.single.weightKg, closeTo(70, .01));
  });

  test('ignores malformed and implausible rows', () {
    final values = parseBodyMeasurementsCsv(
      'date,weight\nbad,70\n2026-07-27,2\n',
    );
    expect(values, isEmpty);
  });
}
