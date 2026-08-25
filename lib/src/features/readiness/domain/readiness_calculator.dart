import 'dart:math' as math;

import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';

class ReadinessCalculator {
  const ReadinessCalculator();

  ReadinessResult calculate(RecoveryInput input) {
    final sleep = _sleepScore(input);
    final recovery = _recoveryScore(input);
    final load = _loadScore(input);
    final checkIn = _checkInScore(input);
    final factors = [
      ReadinessFactor(
        label: 'Sleep',
        score: sleep,
        weight: 0.30,
        detail: input.hasSleepData
            ? '${input.sleepMinutes ~/ 60}h ${input.sleepMinutes % 60}m against your ${input.sleepTargetMinutes ~/ 60}h target'
            : 'No sleep data recorded yet',
      ),
      ReadinessFactor(
        label: 'Recovery signals',
        score: recovery,
        weight: 0.30,
        detail: !input.hasRecoverySignals
            ? 'No heart-rate recovery data recorded yet'
            : input.hrvMilliseconds == null
                ? 'Resting heart rate ${input.restingHeartRate.round()} bpm'
                : 'HRV ${input.hrvMilliseconds!.round()} ms and resting heart rate ${input.restingHeartRate.round()} bpm',
      ),
      ReadinessFactor(
        label: 'Training load',
        score: load,
        weight: 0.20,
        detail:
            '${input.recentTrainingLoad.round()} over 7 days versus ${input.normalTrainingLoad.round()} usual',
      ),
      ReadinessFactor(
        label: 'Morning check-in',
        score: checkIn,
        weight: 0.20,
        detail: input.hasCheckIn
            ? 'Fatigue ${input.fatigue}/5, soreness ${input.soreness}/5, stress ${input.stress}/5'
            : 'Morning check-in not completed',
      ),
    ];
    final score = factors
        .fold<double>(
            0, (total, factor) => total + factor.score * factor.weight)
        .round()
        .clamp(0, 100)
        .toInt();
    final band = score >= 67
        ? ReadinessBand.high
        : score >= 34
            ? ReadinessBand.moderate
            : ReadinessBand.low;

    return ReadinessResult(
      score: score,
      band: band,
      headline: switch (band) {
        ReadinessBand.high => 'Ready to train',
        ReadinessBand.moderate => 'Train with care',
        ReadinessBand.low => 'Prioritise recovery',
      },
      recommendation: switch (band) {
        ReadinessBand.high =>
          'Your recovery signals support the planned session. Warm up and reassess before hard efforts.',
        ReadinessBand.moderate =>
          'Keep the session easy to moderate, or shorten it if your legs do not improve during the warm-up.',
        ReadinessBand.low =>
          'Choose rest or a short recovery ride today. Persistent unusual readings deserve extra attention.',
      },
      factors: factors,
    );
  }

  double _sleepScore(RecoveryInput input) {
    if (!input.hasSleepData || input.sleepMinutes <= 0) return 50;
    final duration = input.sleepTargetMinutes <= 0
        ? 0.0
        : input.sleepMinutes / input.sleepTargetMinutes;
    return _clamp100((duration.clamp(0.0, 1.1) / 1.1 * 70) +
        input.sleepQuality.clamp(0, 100) * 0.30);
  }

  double _recoveryScore(RecoveryInput input) {
    if (!input.hasRecoverySignals) return 50;
    final rhrDelta = input.restingHeartRate - input.baselineRestingHeartRate;
    final rhrScore = 100 - math.max(0, rhrDelta) * 8;
    if (input.hrvMilliseconds == null ||
        input.baselineHrvMilliseconds == null ||
        input.baselineHrvMilliseconds! <= 0) {
      return _clamp100(rhrScore);
    }
    final hrvRatio = input.hrvMilliseconds! / input.baselineHrvMilliseconds!;
    final hrvScore = (hrvRatio * 100).clamp(35, 110).toDouble();
    return _clamp100(rhrScore * 0.5 + hrvScore * 0.5);
  }

  double _loadScore(RecoveryInput input) {
    if (input.normalTrainingLoad <= 0) return 70;
    final ratio = input.recentTrainingLoad / input.normalTrainingLoad;
    if (ratio <= 1) return 100 - (1 - ratio).abs() * 15;
    return _clamp100(100 - (ratio - 1) * 80);
  }

  double _checkInScore(RecoveryInput input) {
    if (!input.hasCheckIn) return 50;
    final positiveMotivation = input.motivation.clamp(1, 5) * 20;
    final fatigue = (6 - input.fatigue.clamp(1, 5)) * 20;
    final soreness = (6 - input.soreness.clamp(1, 5)) * 20;
    final stress = (6 - input.stress.clamp(1, 5)) * 20;
    return (positiveMotivation + fatigue + soreness + stress) / 4;
  }

  double _clamp100(num value) => value.clamp(0, 100).toDouble();
}
