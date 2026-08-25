class AiReadinessResult {
  const AiReadinessResult({
    required this.score,
    required this.status,
    required this.contributingFactors,
    required this.positiveFactors,
    required this.warningFactors,
  });

  final int score;
  final String status;
  final List<String> contributingFactors;
  final List<String> positiveFactors;
  final List<String> warningFactors;

  Map<String, Object?> toJson() => {
        'score': {'label': 'CALCULATED', 'value': score},
        'status': {'label': 'CALCULATED', 'value': status},
        'contributingFactors': contributingFactors,
        'positiveFactors': positiveFactors,
        'warningFactors': warningFactors,
      };
}

class AiReadinessEngine {
  const AiReadinessEngine();

  AiReadinessResult calculate({
    double? hrv,
    double? hrvBaseline,
    double? restingHr,
    double? restingHrBaseline,
    double? sleepHours,
    double? sleepTargetHours,
    double? load7Days,
    double? usualLoad7Days,
    int? hardSessions7Days,
    double? form,
    int? recoveryHours,
    int? fatigue,
  }) {
    final scored = <({double score, double weight, String detail})>[];
    final positive = <String>[];
    final warnings = <String>[];
    void add(double score, double weight, String detail) => scored.add((
          score: score.clamp(0, 100),
          weight: weight,
          detail: detail,
        ));
    if (hrv != null && hrvBaseline != null && hrvBaseline > 0) {
      final ratio = hrv / hrvBaseline;
      add((ratio * 100).clamp(35, 100), 25, 'HRV versus personal baseline');
      (ratio >= .95 ? positive : warnings).add(
        ratio >= .95
            ? 'HRV is close to or above your baseline.'
            : 'HRV is below your personal baseline.',
      );
    }
    if (restingHr != null && restingHrBaseline != null) {
      final delta = restingHr - restingHrBaseline;
      add(100 - delta.clamp(0, 15) * 6, 20,
          'Resting heart rate versus personal baseline');
      (delta <= 2 ? positive : warnings).add(
        delta <= 2
            ? 'Resting heart rate is near your baseline.'
            : 'Resting heart rate is elevated.',
      );
    }
    if (sleepHours != null &&
        sleepTargetHours != null &&
        sleepTargetHours > 0) {
      final ratio = sleepHours / sleepTargetHours;
      add((ratio * 100).clamp(30, 100), 20, 'Sleep versus your target');
      (ratio >= .9 ? positive : warnings).add(
        ratio >= .9 ? 'Sleep was close to target.' : 'Sleep was below target.',
      );
    }
    if (load7Days != null && usualLoad7Days != null && usualLoad7Days > 0) {
      final ratio = load7Days / usualLoad7Days;
      add(ratio <= 1.15 ? 90 : 90 - (ratio - 1.15) * 100, 15,
          'Seven-day load versus your normal load');
      if (ratio > 1.3) warnings.add('Training load rose sharply this week.');
    }
    if (form != null) {
      add((75 + form).clamp(20, 100), 10, 'Fitness versus fatigue balance');
      if (form < -20) warnings.add('Fatigue is high relative to fitness.');
    }
    if (recoveryHours != null) {
      add((100 - recoveryHours * 1.5).clamp(15, 100), 5,
          'Remaining recovery time');
    }
    if (fatigue != null) {
      add((6 - fatigue.clamp(1, 5)) * 20, 5, 'Morning fatigue check-in');
    }
    if (hardSessions7Days != null && hardSessions7Days >= 3) {
      warnings
          .add('$hardSessions7Days hard sessions were completed this week.');
    }
    final weight = scored.fold<double>(0, (sum, item) => sum + item.weight);
    final score = weight == 0
        ? 50
        : (scored.fold<double>(
                    0, (sum, item) => sum + item.score * item.weight) /
                weight)
            .round()
            .clamp(0, 100);
    final status = score >= 86
        ? 'Excellent'
        : score >= 71
            ? 'Good'
            : score >= 51
                ? 'Moderate'
                : score >= 31
                    ? 'Low'
                    : 'Very Low';
    return AiReadinessResult(
      score: score,
      status: status,
      contributingFactors: scored.map((item) => item.detail).toList(),
      positiveFactors: positive,
      warningFactors: warnings,
    );
  }
}
