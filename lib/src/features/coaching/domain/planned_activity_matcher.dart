class PlannedMatchCandidate {
  const PlannedMatchCandidate({
    required this.id,
    required this.day,
    required this.sessionType,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
  });

  final String id;
  final DateTime day;
  final String sessionType;
  final String title;
  final int durationMinutes;
  final int targetLoad;
}

class CompletedRideCandidate {
  const CompletedRideCandidate({
    required this.id,
    required this.startedAt,
    required this.title,
    required this.durationMinutes,
    required this.trainingLoad,
  });

  final String id;
  final DateTime startedAt;
  final String title;
  final int durationMinutes;
  final int? trainingLoad;
}

class PlannedActivityMatch {
  const PlannedActivityMatch({
    required this.planned,
    required this.ride,
    required this.confidence,
    required this.reason,
  });

  final PlannedMatchCandidate planned;
  final CompletedRideCandidate ride;
  final double confidence;
  final String reason;
}

PlannedActivityMatch? matchPlannedActivity({
  required Iterable<PlannedMatchCandidate> planned,
  required CompletedRideCandidate ride,
}) {
  ({PlannedMatchCandidate plan, double score, int shared})? best;
  for (final plan in planned) {
    if (plan.sessionType == 'rest' || plan.durationMinutes <= 0) continue;
    final dayGap = _day(plan.day).difference(_day(ride.startedAt)).inDays.abs();
    if (dayGap > 1) continue;
    final shared = _tokens(plan.title).intersection(_tokens(ride.title)).length;
    var score = dayGap == 0 ? 55.0 : 15.0;
    score += _ratioScore(plan.durationMinutes, ride.durationMinutes, 20);
    if (plan.targetLoad > 0 && ride.trainingLoad != null) {
      score += _ratioScore(plan.targetLoad, ride.trainingLoad!, 15);
    }
    score += (shared * 8).clamp(0, 24);
    if (best == null || score > best.score) {
      best = (plan: plan, score: score, shared: shared);
    }
  }
  if (best == null) return null;
  final gap = _day(best.plan.day).difference(_day(ride.startedAt)).inDays.abs();
  final threshold = gap == 0 ? 60 : 55;
  if (best.score < threshold || (gap == 1 && best.shared == 0)) return null;
  return PlannedActivityMatch(
    planned: best.plan,
    ride: ride,
    confidence: (best.score / 100).clamp(.0, 1.0),
    reason: gap == 0
        ? 'Matched on calendar date, duration, load and session name where available.'
        : 'Matched across the adjacent date using the session name and workout shape.',
  );
}

double _ratioScore(int expected, int actual, double maximum) {
  if (expected <= 0 || actual <= 0) return 0;
  final ratio = actual / expected;
  final difference = (1 - ratio).abs();
  return (maximum * (1 - difference)).clamp(0, maximum);
}

Set<String> _tokens(String value) {
  const ignored = {'ride', 'cycling', 'workout', 'session', 'min', 'mins'};
  return value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 3 && !ignored.contains(token))
      .toSet();
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
