class DebriefRide {
  const DebriefRide({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.trainingLoad,
    required this.averagePower,
    required this.averageHeartRate,
    this.title,
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final int? trainingLoad;
  final int? averagePower;
  final int? averageHeartRate;
  final String? title;

  double? get efficiency {
    final power = averagePower;
    final heartRate = averageHeartRate;
    if (power == null || heartRate == null || power <= 0 || heartRate <= 0) {
      return null;
    }
    return power / heartRate;
  }
}

class PostRideDebrief {
  const PostRideDebrief({
    required this.headline,
    required this.summary,
    required this.loadLabel,
    required this.loadComparison,
    required this.efficiencyComparison,
    required this.recoveryAction,
    required this.fuellingAction,
    required this.comparisonRideCount,
  });

  final String headline;
  final String summary;
  final String loadLabel;
  final String loadComparison;
  final String efficiencyComparison;
  final String recoveryAction;
  final String fuellingAction;
  final int comparisonRideCount;
}

PostRideDebrief buildPostRideDebrief({
  required DebriefRide ride,
  required Iterable<DebriefRide> history,
  required double weightKg,
}) {
  final windowStart = ride.startedAt.subtract(const Duration(days: 56));
  final previous = history
      .where((item) =>
          item.id != ride.id &&
          item.startedAt.isBefore(ride.startedAt) &&
          !item.startedAt.isBefore(windowStart))
      .toList();

  final previousLoads =
      previous.map((item) => item.trainingLoad).whereType<int>().toList();
  final averageLoad = previousLoads.isEmpty
      ? null
      : previousLoads.reduce((a, b) => a + b) / previousLoads.length;
  final load = ride.trainingLoad;
  final relativeLoad = load == null || averageLoad == null || averageLoad <= 0
      ? null
      : load / averageLoad;
  final loadLabel = relativeLoad == null
      ? (load == null ? 'Load unavailable' : 'Training load recorded')
      : relativeLoad < .7
          ? 'Easier than usual'
          : relativeLoad > 1.3
              ? 'Demanding ride'
              : 'Typical training load';

  final loadComparison = switch ((load, averageLoad)) {
    (final int value, final double baseline) =>
      '$value load was ${((value / baseline - 1).abs() * 100).round()}% '
          '${value >= baseline ? 'above' : 'below'} your recent ride average.',
    (final int value, null) =>
      '$value training load recorded. More rides will create a personal comparison.',
    _ => 'Training load was not supplied for this ride.',
  };

  final efficiencies =
      previous.map((item) => item.efficiency).whereType<double>().toList();
  final baselineEfficiency = efficiencies.isEmpty
      ? null
      : efficiencies.reduce((a, b) => a + b) / efficiencies.length;
  final efficiency = ride.efficiency;
  final efficiencyChange = efficiency == null || baselineEfficiency == null
      ? null
      : (efficiency / baselineEfficiency - 1) * 100;
  final efficiencyComparison = efficiencyChange == null
      ? 'Power and heart-rate data from more rides will unlock your aerobic efficiency comparison.'
      : '${efficiencyChange.abs().toStringAsFixed(1)}% '
          '${efficiencyChange >= 0 ? 'more' : 'less'} power per heartbeat than your eight-week average.';

  final demanding = (load ?? 0) >= 80 || (relativeLoad ?? 0) > 1.3;
  final moderate = (load ?? 0) >= 40 || (relativeLoad ?? 0) >= .7;
  final headline = demanding
      ? 'Big work banked'
      : moderate
          ? 'Solid session completed'
          : 'Useful miles in the legs';
  final summary = efficiencyChange != null && efficiencyChange >= 3
      ? 'You handled this ride efficiently compared with your recent baseline.'
      : demanding
          ? 'This was a meaningful training stimulus. Let recovery turn it into fitness.'
          : 'This added training without creating unusually high fatigue.';
  final recoveryAction = demanding
      ? 'Keep the next 24–36 hours easy. Prioritise sleep and check tomorrow’s readiness before adding intensity.'
      : moderate
          ? 'Allow an easy 12–24 hours before another hard session.'
          : 'Normal training can continue if tomorrow’s readiness and legs feel good.';

  final safeWeight = weightKg.clamp(40, 150);
  final carbLow = (safeWeight * (demanding ? .9 : .6)).round();
  final carbHigh = (safeWeight * (demanding ? 1.2 : .9)).round();
  final protein = (safeWeight * .3).round();
  final fuellingAction =
      'Aim for about $carbLow–$carbHigh g carbohydrate and $protein g protein '
      'in your next recovery meal, plus fluid to thirst.';

  return PostRideDebrief(
    headline: headline,
    summary: summary,
    loadLabel: loadLabel,
    loadComparison: loadComparison,
    efficiencyComparison: efficiencyComparison,
    recoveryAction: recoveryAction,
    fuellingAction: fuellingAction,
    comparisonRideCount: previous.length,
  );
}
