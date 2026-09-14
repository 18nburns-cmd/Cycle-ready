enum CoachingSessionType {
  recovery,
  endurance,
  longEndurance,
  tempo,
  sweetSpot,
  threshold,
  vo2Max,
  sprint,
  anaerobic,
  eventSpecific,
}

enum SessionOutcome {
  exceeded,
  achieved,
  partiallyAchieved,
  notAchieved,
  achievedHighCost,
}

enum SessionFailureCause {
  fatigue,
  poorRecovery,
  incorrectFtp,
  workoutTooDifficult,
  poorPacing,
  inadequateFueling,
  dehydration,
  heat,
  sleepDeficit,
  illness,
  muscularFatigue,
  cardiovascularLimitation,
  scheduleInterruption,
  dataQuality,
  unknown,
}

enum NextSessionAction {
  keepPlannedSession,
  progress,
  hold,
  reduceVolume,
  reduceIntensity,
  changeToEndurance,
  changeToRecovery,
  rest,
  repeatSimilarSession,
  rebuildWeek,
}

class SessionPurpose {
  const SessionPurpose({
    required this.sessionType,
    required this.primaryAdaptation,
    required this.secondaryAdaptation,
    required this.plannedDurationMinutes,
    required this.targetIntensity,
    required this.keyIntervals,
    required this.successMetrics,
    required this.progressionIfSuccessful,
    required this.actionIfUnsuccessful,
  });

  final CoachingSessionType sessionType;
  final String primaryAdaptation;
  final String secondaryAdaptation;
  final int plannedDurationMinutes;
  final String targetIntensity;
  final List<String> keyIntervals;
  final List<String> successMetrics;
  final String progressionIfSuccessful;
  final String actionIfUnsuccessful;

  Map<String, Object?> toJson() => {
        'session_type': _enumName(sessionType.name),
        'primary_adaptation': primaryAdaptation,
        'secondary_adaptation': secondaryAdaptation,
        'planned_duration': plannedDurationMinutes,
        'target_intensity': targetIntensity,
        'key_intervals': keyIntervals,
        'success_metrics': successMetrics,
        'progression_if_successful': progressionIfSuccessful,
        'action_if_unsuccessful': actionIfUnsuccessful,
      };
}

class SessionOutcomeEvidence {
  const SessionOutcomeEvidence({
    required this.completedDurationMinutes,
    this.intervalCompletionPercent,
    this.powerTargetAchievementPercent,
    this.intervalQualityPercent,
    this.timeInTargetPercent,
    this.powerFadePercent,
    this.pwHrDecouplingPercent,
    this.decouplingIsValid = false,
    this.cadenceStabilityPercent,
    this.rpe,
    this.expectedRpe,
    this.rpeDrift,
    this.nextDayHrvChangePercent,
    this.nextDayRestingHrDelta,
    this.sleepDeficitMinutes,
    this.soreness,
    this.fatigue,
    this.readinessDrop,
    this.unusualPain = false,
    this.illnessSymptoms = false,
    this.inadequateFueling = false,
    this.dehydration = false,
    this.heatExposure = false,
    this.scheduleInterruption = false,
    this.dataQualityAdequate = true,
    this.comparableAchievedSessions = 0,
    this.comparableFailedSessions = 0,
    this.comparableAverageRecoveryCost,
    this.recoveryWasNormal = true,
    this.performanceTrendImproving = false,
    this.readinessStable = true,
  });

  final int completedDurationMinutes;
  final double? intervalCompletionPercent;
  final double? powerTargetAchievementPercent;
  final double? intervalQualityPercent;
  final double? timeInTargetPercent;
  final double? powerFadePercent;
  final double? pwHrDecouplingPercent;
  final bool decouplingIsValid;
  final double? cadenceStabilityPercent;
  final double? rpe;
  final double? expectedRpe;
  final double? rpeDrift;
  final double? nextDayHrvChangePercent;
  final double? nextDayRestingHrDelta;
  final int? sleepDeficitMinutes;
  final int? soreness;
  final int? fatigue;
  final double? readinessDrop;
  final bool unusualPain;
  final bool illnessSymptoms;
  final bool inadequateFueling;
  final bool dehydration;
  final bool heatExposure;
  final bool scheduleInterruption;
  final bool dataQualityAdequate;
  final int comparableAchievedSessions;
  final int comparableFailedSessions;
  final double? comparableAverageRecoveryCost;
  final bool recoveryWasNormal;
  final bool performanceTrendImproving;
  final bool readinessStable;
}

class SessionOutcomeDecision {
  const SessionOutcomeDecision({
    required this.sessionType,
    required this.primaryAdaptation,
    required this.sessionOutcome,
    required this.stimulusAchievementScore,
    required this.recoveryCostScore,
    required this.durabilityScore,
    required this.plannedDurationMinutes,
    required this.completedDurationMinutes,
    required this.intervalCompletionPercent,
    required this.powerTargetAchievementPercent,
    required this.pwHrDecouplingPercent,
    required this.powerFadePercent,
    required this.rpe,
    required this.outcomeReasons,
    required this.possibleFailureCauses,
    required this.coachingInterpretation,
    required this.adaptationAchieved,
    required this.progressionAllowed,
    required this.nextSessionAction,
    required this.nextSessionReason,
    required this.planChangeRequired,
    required this.confidence,
  });

  final CoachingSessionType sessionType;
  final String primaryAdaptation;
  final SessionOutcome sessionOutcome;
  final int stimulusAchievementScore;
  final int recoveryCostScore;
  final int? durabilityScore;
  final int plannedDurationMinutes;
  final int completedDurationMinutes;
  final double? intervalCompletionPercent;
  final double? powerTargetAchievementPercent;
  final double? pwHrDecouplingPercent;
  final double? powerFadePercent;
  final double? rpe;
  final List<String> outcomeReasons;
  final List<SessionFailureCause> possibleFailureCauses;
  final String coachingInterpretation;
  final bool adaptationAchieved;
  final bool progressionAllowed;
  final NextSessionAction nextSessionAction;
  final String nextSessionReason;
  final bool planChangeRequired;
  final double confidence;

  Map<String, Object?> toJson() => {
        'session_type': _enumName(sessionType.name),
        'primary_adaptation': primaryAdaptation,
        'session_outcome': _enumName(sessionOutcome.name),
        'stimulus_achievement_score': stimulusAchievementScore,
        'recovery_cost_score': recoveryCostScore,
        'durability_score': durabilityScore,
        'planned_duration_minutes': plannedDurationMinutes,
        'completed_duration_minutes': completedDurationMinutes,
        'interval_completion_percent': intervalCompletionPercent,
        'power_target_achievement_percent': powerTargetAchievementPercent,
        'pw_hr_decoupling_percent': pwHrDecouplingPercent,
        'power_fade_percent': powerFadePercent,
        'rpe': rpe,
        'outcome_reasons': outcomeReasons,
        'possible_failure_causes': possibleFailureCauses
            .map((cause) => _enumName(cause.name))
            .toList(growable: false),
        'coaching_interpretation': coachingInterpretation,
        'adaptation_achieved': adaptationAchieved,
        'progression_allowed': progressionAllowed,
        'next_session_action': _enumName(nextSessionAction.name),
        'next_session_reason': nextSessionReason,
        'plan_change_required': planChangeRequired,
        'confidence': confidence,
      };
}

class SessionOutcomePolicy {
  const SessionOutcomePolicy();

  SessionOutcomeDecision evaluate({
    required SessionPurpose purpose,
    required SessionOutcomeEvidence evidence,
  }) {
    final stimulus = _stimulus(purpose, evidence);
    final recoveryCost = _recoveryCost(evidence);
    final durability = _durability(purpose.sessionType, evidence);
    final achieved = stimulus >= 75;
    final highCost = recoveryCost >= 70;
    final exceeded = stimulus >= 90 &&
        recoveryCost < 50 &&
        (evidence.rpe == null ||
            evidence.expectedRpe == null ||
            evidence.rpe! <= evidence.expectedRpe!);
    final outcome = achieved && highCost
        ? SessionOutcome.achievedHighCost
        : exceeded
            ? SessionOutcome.exceeded
            : achieved
                ? SessionOutcome.achieved
                : stimulus >= 60
                    ? SessionOutcome.partiallyAchieved
                    : SessionOutcome.notAchieved;
    final causes = _failureCauses(outcome, evidence);
    final progressionAllowed = (outcome == SessionOutcome.achieved ||
            outcome == SessionOutcome.exceeded) &&
        recoveryCost < 60 &&
        evidence.recoveryWasNormal &&
        evidence.readinessStable &&
        evidence.comparableAchievedSessions >= 2;
    final next = _nextAction(
      purpose.sessionType,
      outcome,
      recoveryCost,
      progressionAllowed,
      evidence,
    );
    final availableSignals = [
      evidence.intervalCompletionPercent,
      evidence.powerTargetAchievementPercent,
      evidence.intervalQualityPercent,
      evidence.timeInTargetPercent,
      evidence.rpe,
      evidence.nextDayHrvChangePercent,
      evidence.nextDayRestingHrDelta,
      evidence.fatigue,
      evidence.soreness,
      if (evidence.decouplingIsValid) evidence.pwHrDecouplingPercent,
    ].where((value) => value != null).length;
    final confidence = !evidence.dataQualityAdequate
        ? .35
        : (0.4 + availableSignals * .055).clamp(.4, .95);
    final reasons = _outcomeReasons(
      purpose,
      evidence,
      stimulus,
      recoveryCost,
      durability,
    );

    return SessionOutcomeDecision(
      sessionType: purpose.sessionType,
      primaryAdaptation: purpose.primaryAdaptation,
      sessionOutcome: outcome,
      stimulusAchievementScore: stimulus,
      recoveryCostScore: recoveryCost,
      durabilityScore: durability,
      plannedDurationMinutes: purpose.plannedDurationMinutes,
      completedDurationMinutes: evidence.completedDurationMinutes,
      intervalCompletionPercent: evidence.intervalCompletionPercent,
      powerTargetAchievementPercent: evidence.powerTargetAchievementPercent,
      pwHrDecouplingPercent:
          evidence.decouplingIsValid ? evidence.pwHrDecouplingPercent : null,
      powerFadePercent: evidence.powerFadePercent,
      rpe: evidence.rpe,
      outcomeReasons: List.unmodifiable(reasons),
      possibleFailureCauses: List.unmodifiable(causes),
      coachingInterpretation: _interpretation(outcome, recoveryCost, causes),
      adaptationAchieved: achieved,
      progressionAllowed: progressionAllowed,
      nextSessionAction: next.$1,
      nextSessionReason: next.$2,
      planChangeRequired: next.$1 == NextSessionAction.rebuildWeek,
      confidence: confidence,
    );
  }

  int _stimulus(SessionPurpose purpose, SessionOutcomeEvidence evidence) {
    final duration = purpose.plannedDurationMinutes <= 0
        ? 100.0
        : evidence.completedDurationMinutes /
            purpose.plannedDurationMinutes *
            100;
    final completion = evidence.intervalCompletionPercent ?? duration;
    final target = evidence.powerTargetAchievementPercent ??
        evidence.timeInTargetPercent ??
        duration;
    final quality = evidence.intervalQualityPercent ??
        (evidence.powerFadePercent == null
            ? target
            : 100 - evidence.powerFadePercent!.abs() * 4);
    final rpeFit = evidence.rpe == null || evidence.expectedRpe == null
        ? 75.0
        : 100 - (evidence.rpe! - evidence.expectedRpe!).abs() * 15;
    var score = duration.clamp(0, 100) * .25 +
        completion.clamp(0, 100) * .25 +
        target.clamp(0, 100) * .25 +
        quality.clamp(0, 100) * .15 +
        rpeFit.clamp(0, 100) * .10;
    if (purpose.sessionType == CoachingSessionType.recovery) {
      final easy = evidence.rpe == null ? 75 : 100 - evidence.rpe! * 10;
      score = duration.clamp(0, 100) * .4 +
          easy.clamp(0, 100) * .4 +
          (100 - (evidence.fatigue ?? 2) * 10).clamp(0, 100) * .2;
    }
    return score.round().clamp(0, 100);
  }

  int _recoveryCost(SessionOutcomeEvidence evidence) {
    final values = <double>[
      if (evidence.nextDayHrvChangePercent != null)
        (-evidence.nextDayHrvChangePercent! * 5).clamp(0, 100),
      if (evidence.nextDayRestingHrDelta != null)
        (evidence.nextDayRestingHrDelta! * 10).clamp(0, 100),
      if (evidence.sleepDeficitMinutes != null)
        (evidence.sleepDeficitMinutes! / 1.2).clamp(0, 100),
      if (evidence.soreness != null) (evidence.soreness! * 20.0).clamp(0, 100),
      if (evidence.fatigue != null) (evidence.fatigue! * 20.0).clamp(0, 100),
      if (evidence.readinessDrop != null)
        (evidence.readinessDrop! * 2).clamp(0, 100),
      if (evidence.rpe != null) (evidence.rpe! * 10).clamp(0, 100),
    ];
    if (evidence.illnessSymptoms || evidence.unusualPain) return 100;
    if (values.isEmpty) return 50;
    return (values.reduce((a, b) => a + b) / values.length)
        .round()
        .clamp(0, 100);
  }

  int? _durability(
    CoachingSessionType type,
    SessionOutcomeEvidence evidence,
  ) {
    if (type != CoachingSessionType.endurance &&
        type != CoachingSessionType.longEndurance &&
        type != CoachingSessionType.eventSpecific) {
      return null;
    }
    final values = <double>[
      if (evidence.powerFadePercent != null)
        (100 - evidence.powerFadePercent!.abs() * 5).clamp(0, 100),
      if (evidence.decouplingIsValid && evidence.pwHrDecouplingPercent != null)
        (100 - evidence.pwHrDecouplingPercent!.abs() * 8).clamp(0, 100),
      if (evidence.cadenceStabilityPercent != null)
        evidence.cadenceStabilityPercent!.clamp(0, 100),
      if (evidence.rpeDrift != null)
        (100 - evidence.rpeDrift!.abs() * 15).clamp(0, 100),
    ];
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length)
        .round()
        .clamp(0, 100);
  }

  List<SessionFailureCause> _failureCauses(
    SessionOutcome outcome,
    SessionOutcomeEvidence evidence,
  ) {
    if (outcome == SessionOutcome.achieved ||
        outcome == SessionOutcome.exceeded) {
      return const [];
    }
    final causes = <SessionFailureCause>[
      if (!evidence.dataQualityAdequate) SessionFailureCause.dataQuality,
      if (evidence.illnessSymptoms) SessionFailureCause.illness,
      if (evidence.fatigue != null && evidence.fatigue! >= 4)
        SessionFailureCause.fatigue,
      if (!evidence.recoveryWasNormal) SessionFailureCause.poorRecovery,
      if (evidence.sleepDeficitMinutes != null &&
          evidence.sleepDeficitMinutes! >= 60)
        SessionFailureCause.sleepDeficit,
      if (evidence.inadequateFueling) SessionFailureCause.inadequateFueling,
      if (evidence.dehydration) SessionFailureCause.dehydration,
      if (evidence.heatExposure) SessionFailureCause.heat,
      if (evidence.scheduleInterruption)
        SessionFailureCause.scheduleInterruption,
      if ((evidence.powerFadePercent ?? 0) > 10) SessionFailureCause.poorPacing,
      if (evidence.comparableFailedSessions >= 3 && evidence.recoveryWasNormal)
        SessionFailureCause.incorrectFtp,
    ];
    return causes.isEmpty ? const [SessionFailureCause.unknown] : causes;
  }

  (NextSessionAction, String) _nextAction(
    CoachingSessionType type,
    SessionOutcome outcome,
    int recoveryCost,
    bool progressionAllowed,
    SessionOutcomeEvidence evidence,
  ) {
    if (evidence.illnessSymptoms || evidence.unusualPain) {
      return (
        NextSessionAction.rest,
        'Symptoms or unusual pain require rest and reassessment before training.',
      );
    }
    if (recoveryCost >= 80) {
      return (
        NextSessionAction.changeToRecovery,
        'The achieved work created excessive recovery cost, so absorption takes priority.',
      );
    }
    if (evidence.comparableFailedSessions >= 3) {
      return (
        NextSessionAction.rebuildWeek,
        'Repeated comparable failures justify reviewing prescription and recovery spacing.',
      );
    }
    if (progressionAllowed && type != CoachingSessionType.recovery) {
      return (
        NextSessionAction.progress,
        'At least three comparable sessions were achieved and absorbed; progress one variable slightly.',
      );
    }
    if (outcome == SessionOutcome.achievedHighCost) {
      return (
        NextSessionAction.changeToRecovery,
        'The stimulus was achieved but must be absorbed before more demanding work.',
      );
    }
    if (outcome == SessionOutcome.notAchieved) {
      return (
        evidence.recoveryWasNormal
            ? NextSessionAction.repeatSimilarSession
            : NextSessionAction.reduceVolume,
        evidence.recoveryWasNormal
            ? 'Repeat an achievable version before progressing; one failure does not change FTP.'
            : 'Reduce the smallest training variable while recovery normalises.',
      );
    }
    return (
      NextSessionAction.hold,
      type == CoachingSessionType.recovery
          ? 'Recovery sessions remain easy and are never progressed into harder work.'
          : 'The stimulus remains appropriate; a successful session alone does not require progression.',
    );
  }

  List<String> _outcomeReasons(
    SessionPurpose purpose,
    SessionOutcomeEvidence evidence,
    int stimulus,
    int recoveryCost,
    int? durability,
  ) =>
      [
        'Stimulus achievement was $stimulus/100 against the ${purpose.primaryAdaptation} purpose.',
        'Recovery cost was $recoveryCost/100 from available 12–48 hour evidence.',
        if (durability != null) 'Late-session durability was $durability/100.',
        if (!evidence.decouplingIsValid &&
            evidence.pwHrDecouplingPercent != null)
          'Pw:Hr was excluded because the ride sections were not comparable.',
        if (evidence.comparableAchievedSessions < 2)
          'Fewer than three comparable successful sessions are available, so progression is withheld.',
      ];

  String _interpretation(
    SessionOutcome outcome,
    int recoveryCost,
    List<SessionFailureCause> causes,
  ) {
    final result = switch (outcome) {
      SessionOutcome.exceeded =>
        'The intended adaptation was delivered comfortably.',
      SessionOutcome.achieved =>
        'The intended physiological stimulus was achieved appropriately.',
      SessionOutcome.partiallyAchieved =>
        'Useful training occurred, but the full intended stimulus was not completed.',
      SessionOutcome.notAchieved =>
        'The primary session objective was not achieved.',
      SessionOutcome.achievedHighCost =>
        'The intended stimulus was achieved, but its recovery cost was excessive.',
    };
    final cause = causes.isEmpty
        ? ''
        : ' Possible causes: ${causes.map((value) => _enumName(value.name)).join(', ')}.';
    return '$result Recovery cost was $recoveryCost/100.$cause';
  }
}

String _enumName(String value) => value
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toUpperCase();
