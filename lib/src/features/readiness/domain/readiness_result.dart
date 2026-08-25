enum ReadinessBand { low, moderate, high }

class ReadinessFactor {
  const ReadinessFactor(
      {required this.label,
      required this.score,
      required this.weight,
      required this.detail});

  final String label;
  final double score;
  final double weight;
  final String detail;
}

class ReadinessResult {
  const ReadinessResult({
    required this.score,
    required this.band,
    required this.headline,
    required this.recommendation,
    required this.factors,
  });

  final int score;
  final ReadinessBand band;
  final String headline;
  final String recommendation;
  final List<ReadinessFactor> factors;
}
