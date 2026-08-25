class TrainingInsightEngine {
  const TrainingInsightEngine();

  List<String> analyse({
    required double fitnessRampRate,
    required double form,
    required double load7Days,
    required double load28DayWeeklyAverage,
    required int hardSessions7Days,
    double? hrv,
    double? hrvBaseline,
    double? restingHr,
    double? restingHrBaseline,
    double? sleepHours,
    double? ftpChangePercent,
    double? wattsPerKgChangePercent,
  }) {
    final results = <String>[];
    if (fitnessRampRate > 1) results.add('Fitness is increasing.');
    if (fitnessRampRate < -1) results.add('Fitness is decreasing.');
    if (load28DayWeeklyAverage > 0 &&
        load7Days > load28DayWeeklyAverage * 1.3) {
      results.add('Seven-day load has increased suddenly.');
    }
    if (hrv != null && hrvBaseline != null && hrv < hrvBaseline * .85) {
      results.add('HRV is unusually low versus your baseline.');
    }
    if (restingHr != null &&
        restingHrBaseline != null &&
        restingHr > restingHrBaseline + 5) {
      results.add('Resting heart rate is elevated versus your baseline.');
    }
    if (sleepHours != null && sleepHours < 6.5) {
      results.add('Recent sleep is insufficient for optimal recovery.');
    }
    if (hardSessions7Days >= 3) {
      results.add('High-intensity frequency is elevated this week.');
    }
    if (form < -20) results.add('Fatigue is unusually high.');
    if (ftpChangePercent != null && ftpChangePercent > 1) {
      results.add('FTP is improving.');
    }
    if (wattsPerKgChangePercent != null && wattsPerKgChangePercent < -2) {
      results.add('Watts per kilogram is declining.');
    }
    if (results.isEmpty) {
      results.add('Training and recovery are close to your recent baseline.');
    }
    return results;
  }
}
