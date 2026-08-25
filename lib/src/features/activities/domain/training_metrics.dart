import 'dart:math' as math;

enum LoadConfidence {
  measuredPower,
  measuredHeartRate,
  perceivedEffort,
  unavailable
}

class LoadEstimate {
  const LoadEstimate(this.value, this.confidence);
  final double value;
  final LoadConfidence confidence;
}

class FitnessPoint {
  const FitnessPoint({
    required this.date,
    required this.fitness,
    required this.fatigue,
    required this.form,
    required this.load,
    this.isForecast = false,
  });
  final DateTime date;
  final double fitness;
  final double fatigue;
  final double form;
  final double load;
  final bool isForecast;
}

/// Projects the existing fitness/fatigue state through future calendar load.
/// Planned load is a scenario, not a promise that adaptation will occur.
List<FitnessPoint> projectFitnessForecast({
  required List<FitnessPoint> history,
  required Iterable<({DateTime date, double load})> plannedLoads,
  required DateTime through,
}) {
  if (history.isEmpty) return const [];
  final last = history.last;
  final end = DateTime(through.year, through.month, through.day);
  final dailyLoads = <DateTime, double>{};
  for (final planned in plannedLoads) {
    final day = DateTime(
      planned.date.year,
      planned.date.month,
      planned.date.day,
    );
    if (!day.isAfter(last.date) || day.isAfter(end)) continue;
    dailyLoads[day] = (dailyLoads[day] ?? 0) + planned.load;
  }
  var fitness = last.fitness;
  var fatigue = last.fatigue;
  final forecast = <FitnessPoint>[];
  for (var day = last.date.add(const Duration(days: 1));
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))) {
    final load = dailyLoads[day] ?? 0;
    fitness += (load - fitness) * (1 - math.exp(-1 / 42));
    fatigue += (load - fatigue) * (1 - math.exp(-1 / 7));
    forecast.add(FitnessPoint(
      date: day,
      fitness: fitness,
      fatigue: fatigue,
      form: fitness - fatigue,
      load: load,
      isForecast: true,
    ));
  }
  return forecast;
}

class TrainingMetrics {
  const TrainingMetrics({
    required this.fitness,
    required this.fatigue,
    required this.form,
    required this.weeklyLoad,
    required this.rampRate,
    required this.history,
  });
  final double fitness;
  final double fatigue;
  final double form;
  final double weeklyLoad;
  final double rampRate;
  final List<FitnessPoint> history;

  String get loadWarning {
    if (rampRate > 8) {
      return 'Training load is rising quickly. Prioritise recovery.';
    }
    if (form < -25) return 'Fatigue is high relative to fitness.';
    if (form > 15) return 'You are relatively fresh.';
    return 'Training load is within a productive range.';
  }
}

enum ForecastLoadStatus { maintaining, productive, cautious, excessive }

class FitnessForecastSummary {
  const FitnessForecastSummary({
    required this.fitnessChange,
    required this.endFitness,
    required this.endForm,
    required this.peakFatigue,
    required this.lowestForm,
    required this.status,
  });

  final double fitnessChange;
  final double endFitness;
  final double endForm;
  final double peakFatigue;
  final double lowestForm;
  final ForecastLoadStatus status;

  String get label => switch (status) {
        ForecastLoadStatus.maintaining => 'Maintaining',
        ForecastLoadStatus.productive => 'Productive build',
        ForecastLoadStatus.cautious => 'High fatigue',
        ForecastLoadStatus.excessive => 'Overload risk',
      };
}

FitnessForecastSummary? summariseFitnessForecast({
  required FitnessPoint current,
  required List<FitnessPoint> forecast,
}) {
  if (forecast.isEmpty) return null;
  final end = forecast.last;
  final peakFatigue = forecast
      .map((point) => point.fatigue)
      .fold<double>(forecast.first.fatigue, math.max);
  final lowestForm = forecast
      .map((point) => point.form)
      .fold<double>(forecast.first.form, math.min);
  final change = end.fitness - current.fitness;
  final status = lowestForm < -30
      ? ForecastLoadStatus.excessive
      : lowestForm < -20
          ? ForecastLoadStatus.cautious
          : change >= 1
              ? ForecastLoadStatus.productive
              : ForecastLoadStatus.maintaining;
  return FitnessForecastSummary(
    fitnessChange: change,
    endFitness: end.fitness,
    endForm: end.form,
    peakFatigue: peakFatigue,
    lowestForm: lowestForm,
    status: status,
  );
}

class ReducedLoadScenario {
  const ReducedLoadScenario({
    required this.day,
    required this.originalLoad,
    required this.reducedLoad,
    required this.forecast,
    required this.summary,
  });

  final DateTime day;
  final double originalLoad;
  final double reducedLoad;
  final List<FitnessPoint> forecast;
  final FitnessForecastSummary summary;
}

/// Models a conservative alternative without changing the real calendar.
ReducedLoadScenario? buildReducedLoadScenario({
  required FitnessPoint current,
  required List<FitnessPoint> forecast,
  double reduction = .30,
}) {
  if (forecast.isEmpty || reduction <= 0 || reduction >= 1) return null;
  final hardest = forecast.reduce((a, b) => a.load >= b.load ? a : b);
  if (hardest.load <= 0) return null;
  final reducedLoad = hardest.load * (1 - reduction);
  final scenarioForecast = projectFitnessForecast(
    history: [current],
    plannedLoads: forecast.map((point) => (
          date: point.date,
          load: point.date == hardest.date ? reducedLoad : point.load,
        )),
    through: forecast.last.date,
  );
  final summary = summariseFitnessForecast(
    current: current,
    forecast: scenarioForecast,
  );
  if (summary == null) return null;
  return ReducedLoadScenario(
    day: hardest.date,
    originalLoad: hardest.load,
    reducedLoad: reducedLoad,
    forecast: scenarioForecast,
    summary: summary,
  );
}

class WeeklyLoadTargets {
  const WeeklyLoadTargets({required this.maintain, required this.build});
  final int maintain;
  final int build;
}

WeeklyLoadTargets calculateWeeklyLoadTargets(double fitness) {
  final maintain = math.max(0, fitness * 7).round();
  return WeeklyLoadTargets(
    maintain: maintain,
    build: (maintain * 1.12).round(),
  );
}

double calculateDailyStrain(double load) {
  if (load <= 0) return 0;
  return (21 * (1 - math.exp(-load / 100))).clamp(0, 21);
}

double calculateRolling24HourLoad(
  Iterable<({DateTime finishedAt, double load})> activities,
  DateTime now,
) {
  return activities.fold(0.0, (total, activity) {
    final ageHours = now.difference(activity.finishedAt).inMinutes / 60;
    if (ageHours < 0 || ageHours >= 24) return total;
    return total + activity.load * math.exp(-ageHours / 12);
  });
}

DateTime resolveSleepCycleStart(DateTime now, DateTime? latestSleepEnd) {
  if (latestSleepEnd != null && !latestSleepEnd.isAfter(now)) {
    return latestSleepEnd;
  }
  final todayBoundary = DateTime(now.year, now.month, now.day, 4);
  return now.isBefore(todayBoundary)
      ? todayBoundary.subtract(const Duration(days: 1))
      : todayBoundary;
}

double calculateSleepCycleLoad(
  Iterable<({DateTime finishedAt, double load})> activities,
  DateTime now, {
  DateTime? latestSleepEnd,
}) {
  final boundary = resolveSleepCycleStart(now, latestSleepEnd);
  return activities.fold(0.0, (total, activity) {
    if (activity.finishedAt.isBefore(boundary) ||
        activity.finishedAt.isAfter(now)) {
      return total;
    }
    final ageHours = now.difference(activity.finishedAt).inMinutes / 60;
    return total + activity.load * math.exp(-ageHours / 12);
  });
}

double calculateTrainingLoad({
  required int durationSeconds,
  required int normalisedPower,
  required int ftp,
}) {
  if (durationSeconds <= 0 || normalisedPower <= 0 || ftp <= 0) return 0;
  final intensity = normalisedPower / ftp;
  return durationSeconds / 3600 * intensity * intensity * 100;
}

LoadEstimate estimateActivityLoad({
  required int durationSeconds,
  int? normalisedPower,
  int? averageHeartRate,
  required int ftp,
  required int restingHeartRate,
  required int maximumHeartRate,
  int? perceivedEffort,
}) {
  if (normalisedPower != null && normalisedPower > 0) {
    return LoadEstimate(
      calculateTrainingLoad(
        durationSeconds: durationSeconds,
        normalisedPower: normalisedPower,
        ftp: ftp,
      ),
      LoadConfidence.measuredPower,
    );
  }
  if (averageHeartRate != null && maximumHeartRate > restingHeartRate) {
    final reserve = ((averageHeartRate - restingHeartRate) /
            (maximumHeartRate - restingHeartRate))
        .clamp(0.0, 1.2);
    return LoadEstimate(
      durationSeconds / 3600 * reserve * reserve * 100,
      LoadConfidence.measuredHeartRate,
    );
  }
  if (perceivedEffort != null) {
    return LoadEstimate(
      durationSeconds / 60 * perceivedEffort.clamp(1, 10) / 10,
      LoadConfidence.perceivedEffort,
    );
  }
  return const LoadEstimate(0, LoadConfidence.unavailable);
}

TrainingMetrics calculateFitnessMetrics(
  Iterable<({DateTime date, double load})> activities,
  DateTime now, {
  int historyDays = 90,
}) {
  final end = DateTime(now.year, now.month, now.day);
  final start = end.subtract(Duration(days: historyDays - 1));
  final dailyLoads = <DateTime, double>{};
  for (final activity in activities) {
    final day =
        DateTime(activity.date.year, activity.date.month, activity.date.day);
    dailyLoads[day] = (dailyLoads[day] ?? 0) + activity.load;
  }

  var fitness = 0.0;
  var fatigue = 0.0;
  final history = <FitnessPoint>[];
  for (var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))) {
    final load = dailyLoads[day] ?? 0;
    fitness += (load - fitness) * (1 - math.exp(-1 / 42));
    fatigue += (load - fatigue) * (1 - math.exp(-1 / 7));
    history.add(FitnessPoint(
      date: day,
      fitness: fitness,
      fatigue: fatigue,
      form: fitness - fatigue,
      load: load,
    ));
  }
  final weeklyLoad = history
      .skip(math.max(0, history.length - 7))
      .fold<double>(0, (sum, point) => sum + point.load);
  final priorFitness =
      history.length > 7 ? history[history.length - 8].fitness : 0;
  return TrainingMetrics(
    fitness: fitness,
    fatigue: fatigue,
    form: fitness - fatigue,
    weeklyLoad: weeklyLoad,
    rampRate: fitness - priorFitness,
    history: history,
  );
}
