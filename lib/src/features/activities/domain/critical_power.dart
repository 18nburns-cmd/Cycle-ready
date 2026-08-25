import 'dart:math' as math;

import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';

enum CriticalPowerConfidence { low, medium, high }

class CriticalPowerEstimate {
  const CriticalPowerEstimate({
    required this.watts,
    required this.wPrimeKilojoules,
    required this.confidence,
    required this.fit,
    required this.durations,
  });

  final int watts;
  final double wPrimeKilojoules;
  final CriticalPowerConfidence confidence;
  final double fit;
  final List<int> durations;
}

CriticalPowerEstimate? estimateCriticalPower(List<PowerCurvePoint> curve) {
  final points = curve
      .where((point) => point.seconds >= 180 && point.seconds <= 1800)
      .toList();
  if (points.length < 3) return null;
  final span = points.last.seconds - points.first.seconds;
  if (span < 600) return null;

  final n = points.length.toDouble();
  final meanX = points.fold<double>(0, (sum, p) => sum + p.seconds) / n;
  final meanY =
      points.fold<double>(0, (sum, p) => sum + p.watts * p.seconds) / n;
  var covariance = 0.0;
  var varianceX = 0.0;
  for (final point in points) {
    final x = point.seconds - meanX;
    covariance += x * (point.watts * point.seconds - meanY);
    varianceX += x * x;
  }
  if (varianceX <= 0) return null;
  final cp = covariance / varianceX;
  final wPrime = meanY - cp * meanX;
  if (cp < 80 || cp > 600 || wPrime < 3000 || wPrime > 60000) return null;

  var residual = 0.0;
  var total = 0.0;
  for (final point in points) {
    final actual = point.watts * point.seconds.toDouble();
    final predicted = cp * point.seconds + wPrime;
    residual += math.pow(actual - predicted, 2);
    total += math.pow(actual - meanY, 2);
  }
  final fit = total <= 0 ? 0.0 : (1 - residual / total).clamp(0, 1).toDouble();
  if (fit < .90) return null;
  final confidence = fit >= .985 && points.length >= 5
      ? CriticalPowerConfidence.high
      : fit >= .96 && points.length >= 4
          ? CriticalPowerConfidence.medium
          : CriticalPowerConfidence.low;
  return CriticalPowerEstimate(
    watts: cp.round(),
    wPrimeKilojoules: wPrime / 1000,
    confidence: confidence,
    fit: fit,
    durations: points.map((point) => point.seconds).toList(),
  );
}
