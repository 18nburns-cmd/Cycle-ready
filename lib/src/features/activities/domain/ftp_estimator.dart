import 'dart:math' as math;

const ftpDurations = [180, 300, 480, 720, 1200, 1800, 2400, 3600];

class PowerSample {
  const PowerSample(this.elapsedSeconds, this.watts);
  final int elapsedSeconds;
  final int watts;
}

class PowerRide {
  const PowerRide({
    required this.date,
    required this.durationSeconds,
    required this.samples,
  });

  final DateTime date;
  final int durationSeconds;
  final List<PowerSample> samples;
}

enum FtpConfidence { low, medium, high }

class FtpEstimate {
  const FtpEstimate({
    required this.watts,
    required this.lowWatts,
    required this.highWatts,
    required this.confidence,
    required this.rideCount,
    required this.efforts,
    required this.criticalPower,
  });

  final int watts;
  final int lowWatts;
  final int highWatts;
  final FtpConfidence confidence;
  final int rideCount;
  final Map<int, double> efforts;
  final double? criticalPower;

  int get durationCoverage => efforts.length;
}

FtpEstimate? estimateFtp(
  Iterable<PowerRide> rides, {
  required DateTime now,
  int windowDays = 56,
}) {
  final oldest = now.subtract(Duration(days: windowDays));
  final eligible = rides
      .where((ride) =>
          !ride.date.isBefore(oldest) &&
          !ride.date.isAfter(now.add(const Duration(days: 1))) &&
          ride.samples.any((sample) => sample.watts > 0))
      .toList();
  if (eligible.isEmpty) return null;

  final efforts = <int, double>{};
  for (final ride in eligible) {
    final series = _secondBySecond(ride);
    for (final duration in ftpDurations) {
      if (series.length < duration) continue;
      final best = _bestAverage(series, duration);
      if (best > (efforts[duration] ?? 0)) efforts[duration] = best;
    }
  }
  if (efforts.length < 2) return null;

  final criticalPower = _criticalPower(efforts);
  const ftpFactors = {
    180: .82,
    300: .86,
    480: .89,
    720: .92,
    1200: .95,
    1800: .97,
    2400: .985,
    3600: 1.0,
  };
  const weights = {
    180: .4,
    300: .6,
    480: .8,
    720: 1.0,
    1200: 1.4,
    1800: 1.7,
    2400: 2.0,
    3600: 2.2,
  };
  final candidates = <(double value, double weight)>[
    for (final entry in efforts.entries)
      (entry.value * ftpFactors[entry.key]!, weights[entry.key]!),
    if (criticalPower != null) (criticalPower * .97, 1.5),
  ];
  final median = _median(candidates.map((candidate) => candidate.$1).toList());
  final filtered = candidates
      .where((candidate) => (candidate.$1 - median).abs() <= median * .15)
      .toList();
  final usable = filtered.isEmpty ? candidates : filtered;
  final totalWeight =
      usable.fold<double>(0, (sum, candidate) => sum + candidate.$2);
  final estimate = usable.fold<double>(
          0, (sum, candidate) => sum + candidate.$1 * candidate.$2) /
      totalWeight;
  final hasLongEffort = efforts.keys.any((seconds) => seconds >= 1800);
  final confidence =
      efforts.length >= 6 && eligible.length >= 5 && hasLongEffort
          ? FtpConfidence.high
          : efforts.length >= 4 && eligible.length >= 3
              ? FtpConfidence.medium
              : FtpConfidence.low;
  final range = switch (confidence) {
    FtpConfidence.high => .03,
    FtpConfidence.medium => .05,
    FtpConfidence.low => .08,
  };
  return FtpEstimate(
    watts: estimate.round(),
    lowWatts: (estimate * (1 - range)).round(),
    highWatts: (estimate * (1 + range)).round(),
    confidence: confidence,
    rideCount: eligible.length,
    efforts: efforts,
    criticalPower: criticalPower,
  );
}

List<int> _secondBySecond(PowerRide ride) {
  final length = ride.durationSeconds.clamp(0, 8 * 3600);
  if (length == 0) return const [];
  final samples = [...ride.samples]
    ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  final result = List<int>.filled(length, 0);
  var sampleIndex = 0;
  var currentPower = 0;
  for (var second = 0; second < length; second++) {
    while (sampleIndex < samples.length &&
        samples[sampleIndex].elapsedSeconds <= second) {
      final value = samples[sampleIndex].watts;
      currentPower = value < 0 || value > 2500 ? 0 : value;
      sampleIndex++;
    }
    result[second] = currentPower;
  }
  return result;
}

double _bestAverage(List<int> values, int duration) {
  var sum = values.take(duration).fold<int>(0, (a, b) => a + b);
  var best = sum;
  for (var end = duration; end < values.length; end++) {
    sum += values[end] - values[end - duration];
    best = math.max(best, sum);
  }
  return best / duration;
}

double? _criticalPower(Map<int, double> efforts) {
  final points = efforts.entries
      .where((entry) => entry.key >= 180 && entry.key <= 1200)
      .toList();
  if (points.length < 3) return null;
  final xs = points.map((entry) => 1 / entry.key).toList();
  final ys = points.map((entry) => entry.value).toList();
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY = ys.reduce((a, b) => a + b) / ys.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < xs.length; i++) {
    numerator += (xs[i] - meanX) * (ys[i] - meanY);
    denominator += math.pow(xs[i] - meanX, 2);
  }
  if (denominator == 0) return null;
  final slope = numerator / denominator;
  final intercept = meanY - slope * meanX;
  return intercept > 0 ? intercept : null;
}

double _median(List<double> values) {
  values.sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}
