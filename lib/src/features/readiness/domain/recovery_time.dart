import 'dart:math' as math;

class RecoveryTimeEstimate {
  const RecoveryTimeEstimate({
    required this.remainingHours,
    required this.explanation,
  });

  final int remainingHours;
  final String explanation;

  double get progress => (remainingHours / 96).clamp(0, 1);

  String get displayValue {
    if (remainingHours <= 0) return 'Ready';
    return '${remainingHours}h';
  }
}

/// Estimates time until another demanding session is advisable.
///
/// This is a coaching estimate, not a medical measurement. Completed-session
/// load establishes the initial recovery demand, which falls continuously as
/// time passes. Current recovery signals modify the remaining demand.
RecoveryTimeEstimate calculateRecoveryTime({
  required Iterable<({DateTime finishedAt, double load})> sessions,
  required DateTime now,
  required int readiness,
  required int sleepScore,
  required double form,
  required double acuteFatigue,
  required int perceivedFatigue,
  required int soreness,
}) {
  final activeDemands = <double>[];
  var highestLoad = 0.0;
  for (final session in sessions) {
    final age = now.difference(session.finishedAt);
    if (age.isNegative || age > const Duration(hours: 96)) continue;
    final load = session.load.clamp(0, 300).toDouble();
    if (load <= 0) continue;
    highestLoad = math.max(highestLoad, load);
    final requiredHours = (4 + 3.4 * math.sqrt(load)).clamp(6, 72);
    final remaining = requiredHours - age.inMinutes / 60;
    if (remaining > 0) activeDemands.add(remaining);
  }

  if (activeDemands.isEmpty) {
    return const RecoveryTimeEstimate(
      remainingHours: 0,
      explanation: 'No recent training is creating a recovery-time demand.',
    );
  }

  activeDemands.sort((a, b) => b.compareTo(a));
  var hours = activeDemands.first;
  for (final overlap in activeDemands.skip(1)) {
    hours += overlap * .25;
  }

  // Summary training load tends to understate the post-exercise oxygen and
  // autonomic cost captured continuously by a watch. Add progressively more
  // allowance to demanding sessions while leaving easy activity nearly
  // unchanged. At high load this adds up to 35%, matching Garmin-like ranges.
  final deviceDemandAllowance = 1 + ((highestLoad - 30) / 150).clamp(0.0, .35);
  hours *= deviceDemandAllowance;

  var modifier = 1.0;
  final drivers = <String>[];
  if (readiness < 67) {
    modifier += ((67 - readiness) / 100).clamp(0, .25);
    drivers.add('readiness');
  }
  if (sleepScore < 75) {
    modifier += ((75 - sleepScore) / 150).clamp(0, .2);
    drivers.add('sleep');
  }
  if (form < -8) {
    modifier += ((-form - 8) / 100).clamp(0, .2);
    drivers.add('training fatigue');
  }
  if (acuteFatigue > 70) {
    modifier += ((acuteFatigue - 70) / 300).clamp(0, .12);
    if (!drivers.contains('training fatigue')) drivers.add('training fatigue');
  }
  if (perceivedFatigue >= 4 || soreness >= 4) {
    modifier += .1;
    drivers.add('check-in');
  }

  final remainingHours = (hours * modifier).ceil().clamp(0, 96);
  final detail = drivers.isEmpty
      ? 'Your current recovery signals are supporting the normal estimate.'
      : 'Extra time has been allowed for ${drivers.toSet().join(', ')}.';
  return RecoveryTimeEstimate(
    remainingHours: remainingHours,
    explanation:
        'Estimated from recent cycling and strength load as it decays over time. $detail',
  );
}
