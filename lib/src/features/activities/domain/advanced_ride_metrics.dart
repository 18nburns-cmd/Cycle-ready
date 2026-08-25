import 'dart:math' as math;

class BestPowerEffort {
  const BestPowerEffort({
    required this.seconds,
    required this.watts,
  });

  final int seconds;
  final int watts;

  String get label => switch (seconds) {
        5 => '5 sec',
        60 => '1 min',
        300 => '5 min',
        1200 => '20 min',
        _ => '${seconds}s',
      };
}

class RideMoment {
  const RideMoment(
      {required this.startSeconds,
      required this.endSeconds,
      required this.title,
      required this.detail});
  final int startSeconds;
  final int endSeconds;
  final String title;
  final String detail;
}

class AdvancedRideMetrics {
  const AdvancedRideMetrics({
    required this.bestEfforts,
    required this.aerobicDecouplingPercent,
    required this.averageCadence,
    required this.powerCoveragePercent,
    required this.heartRateCoveragePercent,
    this.matchesBurned = 0,
    this.matchWorkKilojoules = 0,
    this.secondHalfPowerChangePercent,
    this.moments = const [],
  });

  final List<BestPowerEffort> bestEfforts;
  final double? aerobicDecouplingPercent;
  final int? averageCadence;
  final int powerCoveragePercent;
  final int heartRateCoveragePercent;
  final int matchesBurned;
  final double matchWorkKilojoules;
  final double? secondHalfPowerChangePercent;
  final List<RideMoment> moments;

  String get decouplingSummary {
    final value = aerobicDecouplingPercent;
    if (value == null) return 'Not enough paired power and heart-rate data.';
    if (value <= 3) {
      return 'Very stable aerobic efficiency throughout the ride.';
    }
    if (value <= 5) {
      return 'Aerobic efficiency remained within a normal endurance range.';
    }
    return 'Efficiency drifted in the second half; pacing, heat, hydration or endurance may have contributed.';
  }
}

AdvancedRideMetrics calculateAdvancedRideMetrics({
  required int durationSeconds,
  int ftp = 0,
  int? criticalPower,
  required Iterable<
          ({
            int elapsedSeconds,
            int? power,
            int? heartRate,
            int? cadence,
          })>
      samples,
}) {
  final values = samples.toList()
    ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  if (values.isEmpty || durationSeconds <= 0) {
    return const AdvancedRideMetrics(
      bestEfforts: [],
      aerobicDecouplingPercent: null,
      averageCadence: null,
      powerCoveragePercent: 0,
      heartRateCoveragePercent: 0,
      matchesBurned: 0,
      matchWorkKilojoules: 0,
      secondHalfPowerChangePercent: null,
      moments: [],
    );
  }

  final length = math.max(
    durationSeconds + 1,
    values.last.elapsedSeconds + 1,
  );
  final power = List<int?>.filled(length, null);
  final heartRate = List<int?>.filled(length, null);
  final cadence = <int>[];
  for (final sample in values) {
    if (sample.elapsedSeconds < 0 || sample.elapsedSeconds >= length) continue;
    power[sample.elapsedSeconds] = sample.power;
    heartRate[sample.elapsedSeconds] = sample.heartRate;
    if (sample.cadence != null && sample.cadence! > 0) {
      cadence.add(sample.cadence!);
    }
  }

  final efforts = <BestPowerEffort>[];
  for (final window in const [5, 60, 300, 1200]) {
    final best = _bestRollingAverage(power, window);
    if (best != null) {
      efforts.add(BestPowerEffort(seconds: window, watts: best));
    }
  }

  return AdvancedRideMetrics(
    bestEfforts: efforts,
    aerobicDecouplingPercent:
        _aerobicDecoupling(power, heartRate, durationSeconds),
    averageCadence: cadence.isEmpty
        ? null
        : (cadence.reduce((a, b) => a + b) / cadence.length).round(),
    powerCoveragePercent:
        (power.whereType<int>().length / durationSeconds * 100)
            .clamp(0, 100)
            .round(),
    heartRateCoveragePercent:
        (heartRate.whereType<int>().length / durationSeconds * 100)
            .clamp(0, 100)
            .round(),
    matchesBurned: _matches(power, criticalPower ?? 0, ftp).$1,
    matchWorkKilojoules: _matches(power, criticalPower ?? 0, ftp).$2,
    secondHalfPowerChangePercent:
        _secondHalfPowerChange(power, durationSeconds),
    moments: _rideMoments(power, criticalPower ?? 0, ftp),
  );
}

List<RideMoment> _rideMoments(List<int?> power, int criticalPower, int ftp) {
  final moments = <RideMoment>[];
  for (final window in const [60, 300]) {
    final best = _bestRollingMoment(power, window);
    if (best != null) {
      moments.add(RideMoment(
        startSeconds: best.$1,
        endSeconds: best.$1 + window,
        title:
            window == 60 ? 'Best one-minute effort' : 'Best five-minute effort',
        detail: '${best.$2} W average',
      ));
    }
  }
  final threshold = criticalPower > 0 ? criticalPower : ftp * 1.2;
  if (threshold > 0) {
    var start = -1;
    var work = 0.0;
    var bestStart = -1;
    var bestEnd = -1;
    var bestWork = 0.0;
    for (var i = 0; i <= power.length; i++) {
      final watts = i < power.length ? power[i] : null;
      if (watts != null && watts > threshold) {
        start = start < 0 ? i : start;
        work += watts - threshold;
      } else if (start >= 0) {
        if (i - start >= 10 && work > bestWork) {
          bestStart = start;
          bestEnd = i;
          bestWork = work;
        }
        start = -1;
        work = 0;
      }
    }
    if (bestStart >= 0) {
      moments.add(RideMoment(
        startSeconds: bestStart,
        endSeconds: bestEnd,
        title: 'Largest match burned',
        detail:
            '${(bestWork / 1000).toStringAsFixed(1)} kJ above ${criticalPower > 0 ? 'Critical Power' : 'the high-power threshold'}',
      ));
    }
  }
  moments.sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
  return moments;
}

(int, int)? _bestRollingMoment(List<int?> values, int window) {
  if (values.length < window) return null;
  var sum = 0;
  var available = 0;
  var bestWatts = 0;
  var bestStart = -1;
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    if (value != null) {
      sum += value;
      available++;
    }
    if (i >= window) {
      final removed = values[i - window];
      if (removed != null) {
        sum -= removed;
        available--;
      }
    }
    if (i >= window - 1 && available >= window * .9) {
      final watts = (sum / available).round();
      if (watts > bestWatts) {
        bestWatts = watts;
        bestStart = i - window + 1;
      }
    }
  }
  return bestStart < 0 ? null : (bestStart, bestWatts);
}

(int, double) _matches(List<int?> power, int criticalPower, int ftp) {
  if (ftp <= 0) return (0, 0);
  final baseline = criticalPower > 0 ? criticalPower : ftp;
  final threshold = criticalPower > 0 ? criticalPower.toDouble() : ftp * 1.2;
  var matches = 0;
  var secondsAbove = 0;
  var gap = 99;
  var currentSeconds = 0;
  var currentWork = 0.0;
  var totalWork = 0.0;
  void finish() {
    if (currentSeconds >= 10) {
      matches++;
      totalWork += currentWork;
    }
    currentSeconds = 0;
    currentWork = 0;
  }

  for (final watts in power) {
    if (watts != null && watts >= threshold) {
      if (gap > 5) finish();
      currentSeconds++;
      secondsAbove++;
      currentWork += watts - baseline;
      gap = 0;
    } else {
      gap++;
      if (gap > 5) finish();
    }
  }
  finish();
  if (secondsAbove == 0) return (0, 0);
  return (matches, totalWork / 1000);
}

double? _secondHalfPowerChange(List<int?> power, int durationSeconds) {
  if (durationSeconds < 600) return null;
  final midpoint = durationSeconds ~/ 2;
  double? average(int start, int end) {
    final values = power
        .skip(start)
        .take(end - start)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (values.length < (end - start) * .5) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  final first = average(0, midpoint);
  final second = average(midpoint, durationSeconds);
  if (first == null || second == null || first <= 0) return null;
  return (second / first - 1) * 100;
}

int? _bestRollingAverage(List<int?> values, int window) {
  if (values.length < window) return null;
  var sum = 0;
  var available = 0;
  double? best;
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value != null) {
      sum += value;
      available++;
    }
    if (index >= window) {
      final removed = values[index - window];
      if (removed != null) {
        sum -= removed;
        available--;
      }
    }
    if (index >= window - 1 && available >= window * .9) {
      best = math.max(best ?? 0, sum / available);
    }
  }
  return best?.round();
}

double? _aerobicDecoupling(
  List<int?> power,
  List<int?> heartRate,
  int durationSeconds,
) {
  if (durationSeconds < 1200) return null;
  final midpoint = durationSeconds ~/ 2;
  (double, double, int) half(int start, int end) {
    var powerSum = 0.0;
    var heartSum = 0.0;
    var count = 0;
    for (var index = start; index < math.min(end, power.length); index++) {
      final watts = power[index];
      final bpm = heartRate[index];
      if (watts == null || bpm == null || watts <= 0 || bpm <= 0) continue;
      powerSum += watts;
      heartSum += bpm;
      count++;
    }
    return (powerSum, heartSum, count);
  }

  final first = half(0, midpoint);
  final second = half(midpoint, durationSeconds);
  if (first.$3 < midpoint * .5 || second.$3 < midpoint * .5) return null;
  final firstEfficiency = (first.$1 / first.$3) / (first.$2 / first.$3);
  final secondEfficiency = (second.$1 / second.$3) / (second.$2 / second.$3);
  if (firstEfficiency <= 0) return null;
  return ((firstEfficiency - secondEfficiency) / firstEfficiency * 100)
      .clamp(-30, 30);
}
