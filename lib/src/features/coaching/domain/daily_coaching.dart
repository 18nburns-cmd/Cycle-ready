import 'dart:math' as math;

import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/power_development_focus.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';

enum SessionType { rest, recovery, endurance, tempo, intervals }

class DailySession {
  const DailySession({
    required this.date,
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    required this.reason,
    required this.confidence,
    required this.evidence,
  });

  final DateTime date;
  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String reason;
  final double confidence;
  final List<String> evidence;
}

class CoachingResult {
  const CoachingResult({
    required this.today,
    required this.outlook,
    required this.insights,
  });

  final DailySession today;
  final List<DailySession> outlook;
  final List<String> insights;
}

class DailyCoachingEngine {
  const DailyCoachingEngine();

  CoachingResult build({
    required DateTime now,
    required ReadinessResult readiness,
    required RecoveryInput recovery,
    required TrainingMetrics metrics,
    PowerDevelopmentFocus? developmentFocus,
  }) {
    final confidence = _confidence(
      readiness: readiness,
      recovery: recovery,
      metrics: metrics,
      developmentFocus: developmentFocus,
    );
    final evidence = _evidence(
      readiness: readiness,
      recovery: recovery,
      metrics: metrics,
      developmentFocus: developmentFocus,
    );
    final today = _sessionFor(
      date: now,
      score: readiness.score,
      form: metrics.form,
      rampRate: metrics.rampRate,
      recovery: recovery,
      developmentFocus: developmentFocus,
      confidence: confidence,
      evidence: evidence,
    );
    final outlook = <DailySession>[];
    var fitness = metrics.fitness;
    var fatigue = metrics.fatigue;
    var priorLoad = today.targetLoad.toDouble();
    for (var offset = 1; offset <= 7; offset++) {
      fitness += (priorLoad - fitness) * (1 - math.exp(-1 / 42));
      fatigue += (priorLoad - fatigue) * (1 - math.exp(-1 / 7));
      final projectedForm = fitness - fatigue;
      final projectedScore =
          (readiness.score + offset * 2 + projectedForm.clamp(-20, 15) * .4)
              .round()
              .clamp(20, 90);
      final session = _sessionFor(
        date: now.add(Duration(days: offset)),
        score: projectedScore,
        form: projectedForm,
        rampRate: metrics.rampRate,
        recovery: recovery,
        alternateHardDay: offset.isEven,
        confidence: (confidence - offset * .04).clamp(.35, .95),
        evidence: [
          'Projected from todayâ€™s readiness of ${readiness.score}/100.',
          'Projected form is ${projectedForm.toStringAsFixed(1)}.',
          'Confidence reduces as the forecast moves further ahead.',
        ],
      );
      outlook.add(session);
      priorLoad = session.targetLoad.toDouble();
    }
    return CoachingResult(
      today: today,
      outlook: outlook,
      insights: _insights(readiness, recovery, metrics),
    );
  }

  DailySession _sessionFor({
    required DateTime date,
    required int score,
    required double form,
    required double rampRate,
    required RecoveryInput recovery,
    PowerDevelopmentFocus? developmentFocus,
    bool alternateHardDay = true,
    required double confidence,
    required List<String> evidence,
  }) {
    final safetyFlag = recovery.fatigue >= 5 ||
        recovery.soreness >= 5 ||
        recovery.stress >= 5 ||
        form < -25 ||
        rampRate > 8;
    if (score < 34 || safetyFlag) {
      return DailySession(
        date: date,
        type: SessionType.rest,
        title: 'Rest or gentle mobility',
        durationMinutes: 0,
        targetLoad: 0,
        reason: safetyFlag
            ? 'Recovery or training-load signals are outside your normal range.'
            : 'Your readiness is too low for useful training stress.',
        confidence: confidence,
        evidence: evidence,
      );
    }
    if (score < 50 || form < -15) {
      return DailySession(
        date: date,
        type: SessionType.recovery,
        title: 'Easy recovery spin',
        durationMinutes: 35,
        targetLoad: 18,
        reason: 'Keep the legs moving without adding meaningful fatigue.',
        confidence: confidence,
        evidence: evidence,
      );
    }
    if (score < 67 || form < -5 || !alternateHardDay) {
      return DailySession(
        date: date,
        type: SessionType.endurance,
        title: 'Endurance ride',
        durationMinutes: 60,
        targetLoad: 40,
        reason: 'Build aerobic fitness at a controlled, conversational effort.',
        confidence: confidence,
        evidence: evidence,
      );
    }
    if (score < 80) {
      return DailySession(
        date: date,
        type: SessionType.tempo,
        title: 'Tempo intervals',
        durationMinutes: 60,
        targetLoad: 60,
        reason: 'You are recovered enough for productive moderate intensity.',
        confidence: confidence,
        evidence: evidence,
      );
    }
    return _developmentSession(
      date,
      developmentFocus,
      confidence: confidence,
      evidence: evidence,
    );
  }

  DailySession _developmentSession(
    DateTime date,
    PowerDevelopmentFocus? focus, {
    required double confidence,
    required List<String> evidence,
  }) {
    if (focus == null) {
      return DailySession(
        date: date,
        type: SessionType.intervals,
        title: 'Threshold development · 4 × 8 min',
        durationMinutes: 70,
        targetLoad: 78,
        reason:
            'Your recovery supports quality work; threshold is the balanced choice until the power curve has enough comparable durations.',
        confidence: confidence,
        evidence: evidence,
      );
    }
    final prescription = switch (focus.area) {
      PowerDevelopmentArea.sprint => (
          title: 'Neuromuscular sprints · 8 × 12 sec',
          minutes: 50,
          load: 55,
        ),
      PowerDevelopmentArea.anaerobic => (
          title: 'Anaerobic repeatability · 8 × 1 min',
          minutes: 60,
          load: 72,
        ),
      PowerDevelopmentArea.vo2Max => (
          title: 'VO2 max · 5 × 4 min',
          minutes: 65,
          load: 82,
        ),
      PowerDevelopmentArea.threshold => (
          title: 'Threshold development · 4 × 8 min',
          minutes: 70,
          load: 78,
        ),
      PowerDevelopmentArea.endurance => (
          title: 'Sweet spot durability · 3 × 12 min',
          minutes: 75,
          load: 72,
        ),
    };
    return DailySession(
      date: date,
      type: focus.area == PowerDevelopmentArea.endurance
          ? SessionType.tempo
          : SessionType.intervals,
      title: prescription.title,
      durationMinutes: prescription.minutes,
      targetLoad: prescription.load,
      reason:
          'Recovery supports a demanding session, and ${focus.label} is the clearest development area in your current eight-week power profile.',
      confidence: confidence,
      evidence: evidence,
    );
  }

  double _confidence({
    required ReadinessResult readiness,
    required RecoveryInput recovery,
    required TrainingMetrics metrics,
    required PowerDevelopmentFocus? developmentFocus,
  }) {
    final value = .45 +
        (recovery.hasHealthData ? .15 : 0) +
        (recovery.hasCheckIn ? .15 : 0) +
        (metrics.history.isNotEmpty ? .10 : 0) +
        ((developmentFocus?.comparisonCount ?? 0) >= 3 ? .10 : 0) +
        (readiness.factors.length >= 3 ? .05 : 0);
    return value.clamp(.35, .95);
  }

  List<String> _evidence({
    required ReadinessResult readiness,
    required RecoveryInput recovery,
    required TrainingMetrics metrics,
    required PowerDevelopmentFocus? developmentFocus,
  }) {
    final factors = [...readiness.factors]
      ..sort((a, b) => a.score.compareTo(b.score));
    return List.unmodifiable([
      'Readiness is ${readiness.score}/100 (${readiness.band.name}).',
      'Current form is ${metrics.form.toStringAsFixed(1)} and seven-day load is ${metrics.weeklyLoad.round()}.',
      if (factors.isNotEmpty)
        '${factors.first.label} is todayâ€™s lowest recovery factor at ${factors.first.score.round()}/100.',
      if (developmentFocus != null)
        '${developmentFocus.label} is supported by ${developmentFocus.comparisonCount} comparable power-curve durations.',
      if (!recovery.hasHealthData)
        'Sleep, HRV or resting-heart-rate data is missing, which lowers confidence.',
      if (!recovery.hasCheckIn)
        'No morning check-in is available, which lowers confidence.',
    ]);
  }

  List<String> _insights(
    ReadinessResult readiness,
    RecoveryInput recovery,
    TrainingMetrics metrics,
  ) {
    final sorted = [...readiness.factors]
      ..sort((a, b) => a.score.compareTo(b.score));
    final insights = <String>[
      if (sorted.isNotEmpty)
        '${sorted.first.label} is the main limiter today: ${sorted.first.detail}'
      else
        'Readiness factors are still being collected.',
    ];
    if (metrics.form < -15) {
      insights.add('Fatigue is high relative to your current fitness.');
    } else if (metrics.form > 10) {
      insights.add(
          'Your training balance indicates that you are relatively fresh.');
    } else {
      insights.add('Your fitness and fatigue are currently well balanced.');
    }
    if (!recovery.hasHealthData) {
      insights.add('Connect and sync Health Connect for a personalised score.');
    }
    return insights;
  }
}
