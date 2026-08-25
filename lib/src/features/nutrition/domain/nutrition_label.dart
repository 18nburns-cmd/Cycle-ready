class NutritionLabel {
  const NutritionLabel({
    this.name = '',
    this.referenceGrams = 100,
    this.calories = 0,
    this.carbohydrateGrams = 0,
    this.proteinGrams = 0,
    this.fatGrams = 0,
  });

  final String name;
  final double referenceGrams;
  final double calories;
  final double carbohydrateGrams;
  final double proteinGrams;
  final double fatGrams;

  NutritionLabel scaledTo(double portionGrams) {
    final factor = referenceGrams <= 0 ? 0 : portionGrams / referenceGrams;
    return NutritionLabel(
      name: name,
      referenceGrams: portionGrams,
      calories: calories * factor,
      carbohydrateGrams: carbohydrateGrams * factor,
      proteinGrams: proteinGrams * factor,
      fatGrams: fatGrams * factor,
    );
  }
}

class NutritionTextFragment {
  const NutritionTextFragment({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centreY => (top + bottom) / 2;
  double get height => bottom - top;
}

NutritionLabel parseNutritionLabel(
  String rawText, {
  Iterable<NutritionTextFragment> fragments = const [],
}) {
  final text = _normalise(rawText);
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  double valueFor(List<String> labels) {
    for (var index = 0; index < lines.length; index++) {
      final lower = lines[index].toLowerCase();
      if (!labels.any((label) => lower.contains(label))) continue;
      final sameLine = _numbers(lines[index]);
      if (sameLine.isNotEmpty) return sameLine.last;
      if (index + 1 < lines.length) {
        final nextLine = _numbers(lines[index + 1]);
        if (nextLine.isNotEmpty) return nextLine.first;
      }
    }
    return 0;
  }

  double calories() {
    for (var index = 0; index < lines.length; index++) {
      final lower = lines[index].toLowerCase();
      if (!lower.contains('kcal')) continue;
      final values = _numbers(lines[index]);
      if (values.isNotEmpty) return values.last;
    }
    return valueFor(['energy', 'calories']);
  }

  var reference = 100.0;
  final referenceMatch =
      RegExp(r'per\s+(\d+(?:\.\d+)?)\s*g', caseSensitive: false)
          .firstMatch(text);
  if (referenceMatch != null) {
    reference = double.tryParse(referenceMatch.group(1)!) ?? 100;
  } else if (RegExp(r'per\s+(serving|portion)', caseSensitive: false)
      .hasMatch(text)) {
    reference = 1;
  }

  final geometry = fragments.toList();
  double macro(List<String> labels) {
    final lineValue = valueFor(labels);
    final positioned = _positionedValue(geometry, labels);
    // A positioned value is more reliable when OCR split the label and value
    // into separate table columns. Otherwise retain the ordinary line parser.
    return positioned ?? lineValue;
  }

  return NutritionLabel(
    referenceGrams: reference,
    calories: calories(),
    carbohydrateGrams: macro(['carbohydrate', 'carbohydrates', 'carbs']),
    proteinGrams: macro(['protein']),
    fatGrams: macro(['total fat', 'fat']),
  );
}

double? _positionedValue(
  List<NutritionTextFragment> fragments,
  List<String> labels,
) {
  for (final label in fragments) {
    final lower = label.text.toLowerCase();
    if (!labels.any((value) => _isLabel(lower, value))) continue;

    final own = _numbers(_normalise(label.text));
    if (own.isNotEmpty) return own.last;

    final tolerance = (label.height.abs() * .8).clamp(8.0, 28.0);
    final candidates = fragments.where((candidate) {
      if (identical(candidate, label)) return false;
      if ((candidate.centreY - label.centreY).abs() > tolerance) return false;
      if (candidate.right <= label.left) return false;
      return _numbers(_normalise(candidate.text)).isNotEmpty;
    }).toList()
      ..sort((a, b) {
        final aRight = a.left >= label.right ? 0 : 1;
        final bRight = b.left >= label.right ? 0 : 1;
        final side = aRight.compareTo(bRight);
        if (side != 0) return side;
        return a.left.compareTo(b.left);
      });
    if (candidates.isNotEmpty) {
      return _numbers(_normalise(candidates.first.text)).first;
    }
  }
  return null;
}

bool _isLabel(String text, String label) {
  if (!text.contains(label)) return false;
  if (label == 'fat' &&
      (text.contains('saturat') || text.contains('of which'))) {
    return false;
  }
  return true;
}

String _normalise(String value) => value
    .replaceAllMapped(
      RegExp(r'(\d)\s*[,·]\s*(\d)'),
      (match) => '${match.group(1)}.${match.group(2)}',
    )
    .replaceAll(RegExp(r'[Oo](?=\s*[gG]\b)'), '0');

List<double> _numbers(String value) => RegExp(r'\d+(?:\.\d+)?')
    .allMatches(value)
    .map((match) => double.parse(match.group(0)!))
    .toList();
