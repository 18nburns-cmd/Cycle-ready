class ParsedBodyMeasurement {
  const ParsedBodyMeasurement({
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
  });

  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
}

List<ParsedBodyMeasurement> parseBodyMeasurementsCsv(String csv) {
  final lines = csv
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return const [];
  final header = _fields(lines.first).map(_normalise).toList();
  final dateIndex =
      _find(header, const ['date', 'time', 'datetime', 'measuredat']);
  final weightIndex = _find(header, const ['weight', 'weightkg', 'bodyweight']);
  final fatIndex =
      _find(header, const ['bodyfat', 'bodyfatpercent', 'fatpercent']);
  if (dateIndex < 0 || weightIndex < 0) return const [];

  final result = <ParsedBodyMeasurement>[];
  for (final line in lines.skip(1)) {
    final fields = _fields(line);
    if (dateIndex >= fields.length || weightIndex >= fields.length) continue;
    final date = _date(fields[dateIndex]);
    var weight = _number(fields[weightIndex]);
    if (date == null || weight == null) continue;
    final weightHeader = header[weightIndex];
    if (weightHeader.contains('lb') || weight > 180) weight /= 2.2046226218;
    if (weight < 30 || weight > 250) continue;
    final fat = fatIndex >= 0 && fatIndex < fields.length
        ? _number(fields[fatIndex])
        : null;
    result.add(ParsedBodyMeasurement(
      measuredAt: date,
      weightKg: weight,
      bodyFatPercent: fat != null && fat > 0 && fat < 75 ? fat : null,
    ));
  }
  result.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  return result;
}

List<String> _fields(String line) {
  final delimiter = line.contains(';') && !line.contains(',') ? ';' : ',';
  return line
      .split(delimiter)
      .map((value) => value.trim().replaceAll('"', ''))
      .toList();
}

String _normalise(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

int _find(List<String> header, List<String> candidates) {
  for (var index = 0; index < header.length; index++) {
    if (candidates.any((candidate) => header[index].contains(candidate))) {
      return index;
    }
  }
  return -1;
}

double? _number(String value) =>
    double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), ''));

DateTime? _date(String value) {
  final direct = DateTime.tryParse(value);
  if (direct != null) return direct;
  final match =
      RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}
