enum WellnessReportPeriod { week, month, twelveWeeks, year }

enum WellnessReviewConfidence { low, medium, high }

class WellnessReportRide {
  const WellnessReportRide(
      {required this.title,
      required this.startedAt,
      required this.durationSeconds,
      required this.distanceMetres,
      required this.elevationMetres,
      required this.load});
  final String title;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final double elevationMetres;
  final double load;
}

class WellnessReportRecovery {
  const WellnessReportRecovery(
      {required this.day, this.sleepMinutes, this.hrv, this.restingHeartRate});
  final DateTime day;
  final int? sleepMinutes;
  final double? hrv;
  final double? restingHeartRate;
}

class WellnessReportNutrition {
  const WellnessReportNutrition(
      {required this.day,
      required this.calories,
      required this.protein,
      required this.carbohydrate,
      required this.water});
  final DateTime day;
  final int calories;
  final double protein;
  final double carbohydrate;
  final int water;
}

class WellnessPeriodReport {
  const WellnessPeriodReport(
      {required this.period,
      required this.start,
      required this.end,
      required this.rideCount,
      required this.distanceMetres,
      required this.elevationMetres,
      required this.durationSeconds,
      required this.load,
      required this.previousLoad,
      required this.averageSleepHours,
      required this.averageHrv,
      required this.averageRestingHeartRate,
      required this.nutritionDays,
      required this.averageProtein,
      required this.averageCarbohydrate,
      required this.averageWater,
      required this.weightChangeKg,
      required this.bestRide,
      required this.headline,
      required this.summary,
      required this.warning,
      required this.activeWeeks,
      required this.previousActiveWeeks,
      required this.previousAverageHrv,
      required this.previousAverageRestingHeartRate,
      required this.confidence,
      required this.coachingPriorities});
  final WellnessReportPeriod period;
  final DateTime start;
  final DateTime end;
  final int rideCount;
  final double distanceMetres;
  final double elevationMetres;
  final int durationSeconds;
  final double load;
  final double previousLoad;
  final double? averageSleepHours;
  final double? averageHrv;
  final double? averageRestingHeartRate;
  final int nutritionDays;
  final double? averageProtein;
  final double? averageCarbohydrate;
  final double? averageWater;
  final double? weightChangeKg;
  final WellnessReportRide? bestRide;
  final String headline;
  final String summary;
  final String? warning;
  final int activeWeeks;
  final int previousActiveWeeks;
  final double? previousAverageHrv;
  final double? previousAverageRestingHeartRate;
  final WellnessReviewConfidence confidence;
  final List<String> coachingPriorities;
}

WellnessPeriodReport buildWellnessPeriodReport(
    {required DateTime now,
    required WellnessReportPeriod period,
    required List<WellnessReportRide> rides,
    required List<WellnessReportRecovery> recovery,
    required List<WellnessReportNutrition> nutrition,
    required List<({DateTime at, double kg})> weights}) {
  final end =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final start = switch (period) {
    WellnessReportPeriod.week => end.subtract(const Duration(days: 7)),
    WellnessReportPeriod.month => DateTime(now.year, now.month, 1),
    WellnessReportPeriod.twelveWeeks => end.subtract(const Duration(days: 84)),
    WellnessReportPeriod.year => DateTime(now.year, 1, 1)
  };
  final length = end.difference(start);
  final previousStart = start.subtract(length);
  final currentRides = rides
      .where((r) => !r.startedAt.isBefore(start) && r.startedAt.isBefore(end))
      .toList();
  final previousRides = rides
      .where((r) =>
          !r.startedAt.isBefore(previousStart) && r.startedAt.isBefore(start))
      .toList();
  final currentRecovery = recovery
      .where((r) => !r.day.isBefore(start) && r.day.isBefore(end))
      .toList();
  final previousRecovery = recovery
      .where((r) => !r.day.isBefore(previousStart) && r.day.isBefore(start))
      .toList();
  final currentNutrition = nutrition
      .where((r) => !r.day.isBefore(start) && r.day.isBefore(end))
      .toList();
  final currentWeights = weights
      .where((r) => !r.at.isBefore(start) && r.at.isBefore(end))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final load = currentRides.fold<double>(0, (s, r) => s + r.load);
  final previousLoad = previousRides.fold<double>(0, (s, r) => s + r.load);
  final best = currentRides.isEmpty
      ? null
      : ([...currentRides]..sort((a, b) => b.load.compareTo(a.load))).first;
  double? avg(Iterable<num?> values) {
    final valid = values.whereType<num>().map((e) => e.toDouble()).toList();
    return valid.isEmpty ? null : valid.reduce((a, b) => a + b) / valid.length;
  }

  final loadChange = previousLoad <= 0 ? null : (load / previousLoad - 1) * 100;
  final headline = currentRides.isEmpty
      ? 'A recovery-focused period so far'
      : loadChange == null
          ? 'A new baseline is forming'
          : loadChange > 10
              ? 'Training load is building'
              : loadChange < -10
                  ? 'Training load has eased'
                  : 'Training is holding steady';
  final currentHrv = avg(currentRecovery.map((r) => r.hrv));
  final priorHrv = avg(previousRecovery.map((r) => r.hrv));
  final currentRhr = avg(currentRecovery.map((r) => r.restingHeartRate));
  final priorRhr = avg(previousRecovery.map((r) => r.restingHeartRate));
  int activeWeeks(List<WellnessReportRide> values, DateTime blockEnd) => values
      .map((r) =>
          blockEnd
              .difference(DateTime(
                  r.startedAt.year, r.startedAt.month, r.startedAt.day))
              .inDays ~/
          7)
      .toSet()
      .length;
  final currentActiveWeeks = activeWeeks(currentRides, end);
  final priorActiveWeeks = activeWeeks(previousRides, start);
  final evidenceDays = currentRecovery
      .where((r) => r.hrv != null || r.restingHeartRate != null)
      .length;
  final confidence = currentRides.length >= 12 && evidenceDays >= 28
      ? WellnessReviewConfidence.high
      : currentRides.length >= 6 && evidenceDays >= 10
          ? WellnessReviewConfidence.medium
          : WellnessReviewConfidence.low;
  final priorities = <String>[];
  if (previousLoad > 0 && load > previousLoad * 1.2) {
    priorities.add(
        'Consolidate the load increase with recovery before adding another large progression.');
  } else if (previousLoad > 0 && load < previousLoad * .8) {
    priorities.add(
        'Rebuild weekly consistency gradually rather than replacing missed work with one large ride.');
  } else {
    priorities.add('Keep the current load progression steady and repeatable.');
  }
  if (currentActiveWeeks < 10 && period == WellnessReportPeriod.twelveWeeks) {
    priorities.add(
        'Aim for a more consistent weekly rhythm across the next training block.');
  }
  if (currentHrv != null && priorHrv != null && currentHrv < priorHrv * .9) {
    priorities.add(
        'Protect sleep and easy days while HRV remains below the preceding block.');
  } else if (evidenceDays < 10) {
    priorities.add(
        'Record more recovery days so the next review can distinguish adaptation from fatigue.');
  }
  final warning = currentRecovery.where((r) => r.hrv != null).length >= 3 &&
          previousRecovery.where((r) => r.hrv != null).length >= 3 &&
          currentHrv != null &&
          priorHrv != null &&
          priorHrv > 0 &&
          currentRhr != null &&
          priorRhr != null &&
          currentHrv < priorHrv * .85 &&
          currentRhr > priorRhr + 3
      ? 'HRV is more than 15% below the preceding period while resting heart rate is over 3 bpm higher. Consider recovery and how you feel before adding intensity.'
      : null;
  return WellnessPeriodReport(
      period: period,
      start: start,
      end: end,
      rideCount: currentRides.length,
      distanceMetres: currentRides.fold(0, (s, r) => s + r.distanceMetres),
      elevationMetres: currentRides.fold(0, (s, r) => s + r.elevationMetres),
      durationSeconds: currentRides.fold(0, (s, r) => s + r.durationSeconds),
      load: load,
      previousLoad: previousLoad,
      averageSleepHours: avg(currentRecovery
          .map((r) => r.sleepMinutes == null ? null : r.sleepMinutes! / 60)),
      averageHrv: avg(currentRecovery.map((r) => r.hrv)),
      averageRestingHeartRate:
          avg(currentRecovery.map((r) => r.restingHeartRate)),
      nutritionDays: currentNutrition.length,
      averageProtein: avg(currentNutrition.map((r) => r.protein)),
      averageCarbohydrate: avg(currentNutrition.map((r) => r.carbohydrate)),
      averageWater: avg(currentNutrition.map((r) => r.water)),
      weightChangeKg: currentWeights.length < 2
          ? null
          : currentWeights.last.kg - currentWeights.first.kg,
      bestRide: best,
      headline: headline,
      summary: loadChange == null
          ? '${currentRides.length} rides and ${load.round()} load are recorded in this period.'
          : 'Training load is ${loadChange.abs().round()}% ${loadChange >= 0 ? 'higher' : 'lower'} than the preceding equivalent period.',
      warning: warning,
      activeWeeks: currentActiveWeeks,
      previousActiveWeeks: priorActiveWeeks,
      previousAverageHrv: priorHrv,
      previousAverageRestingHeartRate: priorRhr,
      confidence: confidence,
      coachingPriorities: priorities.take(3).toList());
}
