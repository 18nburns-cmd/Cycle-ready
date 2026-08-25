import 'dart:math' as math;

enum InsightConfidence { low, medium, high }

class InsightRide {
  const InsightRide({
    required this.startedAt,
    required this.trainingLoad,
    this.averagePower,
    this.averageHeartRate,
  });

  final DateTime startedAt;
  final double trainingLoad;
  final double? averagePower;
  final double? averageHeartRate;
}

class InsightRecoveryDay {
  const InsightRecoveryDay({
    required this.day,
    this.sleepMinutes,
    this.restingHeartRate,
  });

  final DateTime day;
  final int? sleepMinutes;
  final double? restingHeartRate;
}

class InsightNutritionDay {
  const InsightNutritionDay({
    required this.day,
    required this.carbohydrateGrams,
  });

  final DateTime day;
  final double carbohydrateGrams;
}

class PersonalInsight {
  const PersonalInsight({
    required this.title,
    required this.message,
    required this.confidence,
    required this.sampleSize,
    required this.kind,
  });

  final String title;
  final String message;
  final InsightConfidence confidence;
  final int sampleSize;
  final String kind;
}

class PersonalInsightsReport {
  const PersonalInsightsReport({
    required this.headline,
    required this.summary,
    required this.insights,
    required this.priorities,
    required this.rideCount,
    required this.recoveryDays,
    required this.nutritionDays,
    required this.currentFourWeekLoad,
    required this.previousFourWeekLoad,
  });

  final String headline;
  final String summary;
  final List<PersonalInsight> insights;
  final List<String> priorities;
  final int rideCount;
  final int recoveryDays;
  final int nutritionDays;
  final double currentFourWeekLoad;
  final double previousFourWeekLoad;
}

class PersonalInsightsEngine {
  const PersonalInsightsEngine();

  PersonalInsightsReport build({
    required DateTime now,
    required List<InsightRide> rides,
    required List<InsightRecoveryDay> recovery,
    required List<InsightNutritionDay> nutrition,
  }) {
    final today = _day(now);
    final windowStart = today.subtract(const Duration(days: 55));
    final midpoint = today.subtract(const Duration(days: 27));
    final inWindow =
        rides.where((ride) => !ride.startedAt.isBefore(windowStart)).toList();
    final previous =
        inWindow.where((ride) => ride.startedAt.isBefore(midpoint)).toList();
    final current =
        inWindow.where((ride) => !ride.startedAt.isBefore(midpoint)).toList();
    final previousLoad =
        previous.fold<double>(0, (sum, ride) => sum + ride.trainingLoad);
    final currentLoad =
        current.fold<double>(0, (sum, ride) => sum + ride.trainingLoad);
    final insights = <PersonalInsight>[
      _loadInsight(currentLoad, previousLoad, inWindow.length),
    ];

    final efficiency = _efficiencyInsight(current, previous);
    if (efficiency != null) insights.add(efficiency);

    final sleep = _sleepInsight(inWindow, recovery);
    if (sleep != null) insights.add(sleep);

    final carbohydrate = _carbohydrateInsight(inWindow, nutrition);
    if (carbohydrate != null) insights.add(carbohydrate);

    final heartRate = _restingHeartRateInsight(today, recovery);
    if (heartRate != null) insights.add(heartRate);

    insights.add(_consistencyInsight(today, inWindow));
    insights.sort((a, b) => b.confidence.index.compareTo(a.confidence.index));

    final priorities = _priorities(
      currentLoad: currentLoad,
      previousLoad: previousLoad,
      recovery: recovery,
      nutrition: nutrition,
      insights: insights,
    );
    final change = previousLoad == 0
        ? null
        : ((currentLoad - previousLoad) / previousLoad) * 100;
    final headline = inWindow.length < 4
        ? 'Your personal baseline is taking shape'
        : change == null
            ? 'A new training block is underway'
            : change > 8
                ? 'Training momentum is building'
                : change < -8
                    ? 'Your recent load has eased'
                    : 'Your training is holding steady';
    final summary = inWindow.length < 4
        ? 'Sync a few more rides and recovery days to unlock stronger personal comparisons.'
        : 'This report compares your latest four weeks with the four weeks before it and looks for repeatable relationships in your own data.';

    return PersonalInsightsReport(
      headline: headline,
      summary: summary,
      insights: insights,
      priorities: priorities,
      rideCount: inWindow.length,
      recoveryDays: recovery.length,
      nutritionDays: nutrition.length,
      currentFourWeekLoad: currentLoad,
      previousFourWeekLoad: previousLoad,
    );
  }

  PersonalInsight _loadInsight(
    double current,
    double previous,
    int sampleSize,
  ) {
    if (previous <= 0) {
      return PersonalInsight(
        title: 'Training-load baseline',
        message:
            'The latest four weeks contain ${current.round()} load. Another training block will make the comparison more meaningful.',
        confidence: _confidence(sampleSize),
        sampleSize: sampleSize,
        kind: 'load',
      );
    }
    final change = ((current - previous) / previous) * 100;
    final direction = change.abs() < 5
        ? 'is broadly stable'
        : change > 0
            ? 'has increased'
            : 'has decreased';
    return PersonalInsight(
      title: 'Four-week training load',
      message:
          'Your load $direction by ${change.abs().round()}% (${previous.round()} to ${current.round()}).',
      confidence: _confidence(sampleSize),
      sampleSize: sampleSize,
      kind: 'load',
    );
  }

  PersonalInsight? _efficiencyInsight(
    List<InsightRide> current,
    List<InsightRide> previous,
  ) {
    double? averageEfficiency(List<InsightRide> values) {
      final valid = values
          .where((ride) =>
              (ride.averagePower ?? 0) > 0 && (ride.averageHeartRate ?? 0) > 0)
          .map((ride) => ride.averagePower! / ride.averageHeartRate!)
          .toList();
      return valid.isEmpty ? null : _average(valid);
    }

    final recentValue = averageEfficiency(current);
    final priorValue = averageEfficiency(previous);
    final count = [...current, ...previous]
        .where((ride) =>
            (ride.averagePower ?? 0) > 0 && (ride.averageHeartRate ?? 0) > 0)
        .length;
    if (recentValue == null || priorValue == null) return null;
    final change = ((recentValue - priorValue) / priorValue) * 100;
    return PersonalInsight(
      title: 'Power-to-heart-rate efficiency',
      message: change.abs() < 2
          ? 'Average cycling efficiency is stable between the two four-week blocks.'
          : 'Average power per heartbeat is ${change > 0 ? 'up' : 'down'} ${change.abs().toStringAsFixed(1)}% in the latest four weeks.',
      confidence: _confidence(count),
      sampleSize: count,
      kind: 'efficiency',
    );
  }

  PersonalInsight? _sleepInsight(
    List<InsightRide> rides,
    List<InsightRecoveryDay> recovery,
  ) {
    final byDay = {
      for (final item in recovery)
        if (item.sleepMinutes != null) _key(item.day): item.sleepMinutes! / 60,
    };
    final pairs = <(double, double)>[];
    for (final ride in rides) {
      final sleep = byDay[_key(ride.startedAt)];
      if (sleep == null ||
          (ride.averagePower ?? 0) <= 0 ||
          (ride.averageHeartRate ?? 0) <= 0) {
        continue;
      }
      pairs.add((sleep, ride.averagePower! / ride.averageHeartRate!));
    }
    if (pairs.length < 3) return null;
    final correlation = _correlation(pairs);
    return PersonalInsight(
      title: 'Sleep and ride efficiency',
      message: correlation.abs() < .2
          ? 'No clear relationship between sleep duration and power-to-heart-rate efficiency is visible yet.'
          : '${correlation > 0 ? 'Longer' : 'Shorter'} sleep has been associated with better power-to-heart-rate efficiency in your matched rides.',
      confidence: _confidence(pairs.length, correlation.abs()),
      sampleSize: pairs.length,
      kind: 'sleep',
    );
  }

  PersonalInsight? _carbohydrateInsight(
    List<InsightRide> rides,
    List<InsightNutritionDay> nutrition,
  ) {
    final byDay = {
      for (final item in nutrition) _key(item.day): item.carbohydrateGrams,
    };
    final pairs = <(double, double)>[];
    for (final ride in rides) {
      final carbs = byDay[_key(ride.startedAt)];
      if (carbs == null || carbs <= 0 || ride.trainingLoad <= 0) continue;
      pairs.add((carbs, ride.trainingLoad));
    }
    if (pairs.length < 3) return null;
    final correlation = _correlation(pairs);
    return PersonalInsight(
      title: 'Carbohydrate and completed load',
      message: correlation.abs() < .2
          ? 'Logged carbohydrate and completed ride load do not yet show a clear relationship.'
          : 'Higher-carbohydrate days have coincided with ${correlation > 0 ? 'more' : 'less'} completed training load.',
      confidence: _confidence(pairs.length, correlation.abs()),
      sampleSize: pairs.length,
      kind: 'nutrition',
    );
  }

  PersonalInsight? _restingHeartRateInsight(
    DateTime today,
    List<InsightRecoveryDay> recovery,
  ) {
    final recentStart = today.subtract(const Duration(days: 6));
    final baselineStart = today.subtract(const Duration(days: 27));
    final recent = recovery
        .where((item) =>
            !item.day.isBefore(recentStart) && item.restingHeartRate != null)
        .map((item) => item.restingHeartRate!)
        .toList();
    final baseline = recovery
        .where((item) =>
            !item.day.isBefore(baselineStart) &&
            item.day.isBefore(recentStart) &&
            item.restingHeartRate != null)
        .map((item) => item.restingHeartRate!)
        .toList();
    if (recent.length < 2 || baseline.length < 3) return null;
    final difference = _average(recent) - _average(baseline);
    return PersonalInsight(
      title: 'Resting heart-rate trend',
      message: difference.abs() < 2
          ? 'Your seven-day resting heart rate is close to its recent baseline.'
          : 'Your seven-day resting heart rate is ${difference.abs().toStringAsFixed(1)} bpm ${difference > 0 ? 'above' : 'below'} its prior three-week baseline.',
      confidence: _confidence(recent.length + baseline.length),
      sampleSize: recent.length + baseline.length,
      kind: 'recovery',
    );
  }

  PersonalInsight _consistencyInsight(DateTime today, List<InsightRide> rides) {
    final activeWeeks = <int>{};
    for (final ride in rides) {
      activeWeeks.add(today.difference(_day(ride.startedAt)).inDays ~/ 7);
    }
    return PersonalInsight(
      title: 'Training consistency',
      message:
          'You recorded rides in ${activeWeeks.length} of the last 8 rolling weeks.',
      confidence: _confidence(rides.length),
      sampleSize: rides.length,
      kind: 'consistency',
    );
  }

  List<String> _priorities({
    required double currentLoad,
    required double previousLoad,
    required List<InsightRecoveryDay> recovery,
    required List<InsightNutritionDay> nutrition,
    required List<PersonalInsight> insights,
  }) {
    final result = <String>[];
    if (previousLoad > 0 && currentLoad > previousLoad * 1.25) {
      result.add('Protect recovery while your four-week load is rising.');
    } else if (previousLoad > 0 && currentLoad < previousLoad * .75) {
      result.add(
          'Rebuild consistency gradually rather than chasing one large ride.');
    } else {
      result.add('Keep the current training rhythm consistent.');
    }
    if (recovery.length < 14) {
      result.add(
          'Record sleep or recovery more often to strengthen personal insights.');
    } else {
      result.add(
          'Use the resting heart-rate trend alongside how you feel each morning.');
    }
    if (nutrition.length < 7) {
      result.add(
          'Log ride-day carbohydrate to reveal your personal fuelling pattern.');
    } else {
      result.add(
          'Keep logging fuel consistently so comparisons remain trustworthy.');
    }
    return result.take(3).toList();
  }

  InsightConfidence _confidence(int samples, [double strength = 1]) {
    if (samples >= 12 && strength >= .35) return InsightConfidence.high;
    if (samples >= 6 && strength >= .2) return InsightConfidence.medium;
    return InsightConfidence.low;
  }

  double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  double _correlation(List<(double, double)> pairs) {
    final xMean = _average(pairs.map((pair) => pair.$1).toList());
    final yMean = _average(pairs.map((pair) => pair.$2).toList());
    var numerator = 0.0;
    var xSquares = 0.0;
    var ySquares = 0.0;
    for (final pair in pairs) {
      final x = pair.$1 - xMean;
      final y = pair.$2 - yMean;
      numerator += x * y;
      xSquares += x * x;
      ySquares += y * y;
    }
    final denominator = math.sqrt(xSquares * ySquares);
    return denominator == 0 ? 0 : numerator / denominator;
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  String _key(DateTime value) => '${value.year}-${value.month}-${value.day}';
}
