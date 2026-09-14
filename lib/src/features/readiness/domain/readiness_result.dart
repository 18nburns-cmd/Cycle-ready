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
    this.recoveryScore = 50,
    this.fatigueScore = 50,
    this.confidenceScore = 50,
    required this.band,
    required this.headline,
    required this.recommendation,
    required this.factors,
  });

  final int score;
  final int recoveryScore;
  final int fatigueScore;
  final int confidenceScore;
  final ReadinessBand band;
  final String headline;
  final String recommendation;
  final List<ReadinessFactor> factors;
}
