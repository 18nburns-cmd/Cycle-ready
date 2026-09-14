enum RideDuplicateLikelihood { distinct, possible }

class RideDuplicateCandidate {
  const RideDuplicateCandidate({
    required this.id,
    required this.source,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMetres,
    this.averagePower,
  });

  final String id;
  final String source;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final int? averagePower;
}

class RideDuplicateAssessment {
  const RideDuplicateAssessment({
    required this.likelihood,
    required this.confidence,
    required this.reasons,
  });

  final RideDuplicateLikelihood likelihood;
  final double confidence;
  final List<String> reasons;
}

class PossibleDuplicateRide {
  const PossibleDuplicateRide({
    required this.first,
    required this.second,
    required this.assessment,
  });

  final RideDuplicateCandidate first;
  final RideDuplicateCandidate second;
  final RideDuplicateAssessment assessment;
}

List<PossibleDuplicateRide> findPossibleDuplicateRides(
  Iterable<RideDuplicateCandidate> rides,
) {
  final ordered = rides.toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final matches = <PossibleDuplicateRide>[];
  for (var firstIndex = 0; firstIndex < ordered.length; firstIndex++) {
    for (var secondIndex = firstIndex + 1;
        secondIndex < ordered.length;
        secondIndex++) {
      final first = ordered[firstIndex];
      final second = ordered[secondIndex];
      if (first.startedAt.difference(second.startedAt).abs() >
          const Duration(minutes: 5)) {
        break;
      }
      final assessment = assessPossibleDuplicateRide(first, second);
      if (assessment.likelihood == RideDuplicateLikelihood.possible) {
        matches.add(PossibleDuplicateRide(
          first: first,
          second: second,
          assessment: assessment,
        ));
      }
    }
  }
  return List.unmodifiable(matches);
}

RideDuplicateAssessment assessPossibleDuplicateRide(
  RideDuplicateCandidate first,
  RideDuplicateCandidate second,
) {
  if (first.id == second.id) {
    return const RideDuplicateAssessment(
      likelihood: RideDuplicateLikelihood.distinct,
      confidence: 1,
      reasons: ['The records have the same internal identity.'],
    );
  }
  final startGap = first.startedAt.difference(second.startedAt).abs();
  final longestDuration = first.durationSeconds > second.durationSeconds
      ? first.durationSeconds
      : second.durationSeconds;
  final durationGap = (first.durationSeconds - second.durationSeconds).abs();
  final durationRatio =
      longestDuration == 0 ? 1.0 : durationGap / longestDuration;
  if (startGap > const Duration(minutes: 5) || durationRatio > .08) {
    return const RideDuplicateAssessment(
      likelihood: RideDuplicateLikelihood.distinct,
      confidence: 1,
      reasons: ['Start time or duration differs too much.'],
    );
  }

  final reasons = <String>[
    'Start times are within ${startGap.inMinutes} minutes.',
    'Durations differ by ${(durationRatio * 100).round()}%.',
  ];
  var corroboratingSignals = 0;
  final longestDistance = first.distanceMetres > second.distanceMetres
      ? first.distanceMetres
      : second.distanceMetres;
  if (longestDistance > 0 &&
      (first.distanceMetres - second.distanceMetres).abs() / longestDistance <=
          .05) {
    corroboratingSignals++;
    reasons.add('Distances are within 5%.');
  }
  final firstPower = first.averagePower;
  final secondPower = second.averagePower;
  if (firstPower != null && secondPower != null) {
    final highestPower = firstPower > secondPower ? firstPower : secondPower;
    if (highestPower > 0 &&
        (firstPower - secondPower).abs() / highestPower <= .08) {
      corroboratingSignals++;
      reasons.add('Average powers are within 8%.');
    }
  }
  if (first.source != second.source) {
    corroboratingSignals++;
    reasons.add('The records came from different import sources.');
  }
  if (corroboratingSignals == 0) {
    return const RideDuplicateAssessment(
      likelihood: RideDuplicateLikelihood.distinct,
      confidence: .7,
      reasons: ['Timing is similar but no independent detail agrees.'],
    );
  }
  return RideDuplicateAssessment(
    likelihood: RideDuplicateLikelihood.possible,
    confidence: (.65 + corroboratingSignals * .1).clamp(0, .95).toDouble(),
    reasons: List.unmodifiable(reasons),
  );
}
