enum PolicyAthleteState {
  green,
  yellow,
  orange,
  red,
  overreaching,
  undertrained,
  detraining,
  peaking,
}

enum PolicyDataConfidence { high, medium, low }

enum PolicyDecision {
  keep,
  reduceVolume,
  reduceIntensity,
  reduceVolumeAndIntensity,
  changeToEndurance,
  changeToRecovery,
  rest,
  progress,
  rebuildMicrocycle,
  rebuildBlock,
}

enum PolicyWorkoutIntensity { rest, recovery, endurance, moderate, high }

enum PolicyReasonCode {
  readinessNormal,
  readinessLow,
  readinessHigh,
  hrvSuppressed,
  hrvPositive,
  restingHrElevated,
  sleepDeficit,
  highFatigue,
  highSoreness,
  highStress,
  illnessFlag,
  injuryFlag,
  acuteLoadHigh,
  trainingLoadLow,
  workoutFailed,
  workoutExceeded,
  repeatedWorkoutFailure,
  consistentStrongPerformance,
  missedWorkout,
  multipleMissedWorkouts,
  ftpIncreaseLikely,
  ftpDecreaseLikely,
  deloadRequired,
  eventProximity,
  taperProtection,
  progressionAppropriate,
  recoveryRequired,
  scheduleConstraint,
}

class WorkoutSuccessComponents {
  const WorkoutSuccessComponents({
    required this.completion,
    required this.targetAchievement,
    required this.physiologicalResponse,
    required this.subjectiveResponse,
  });

  final double completion;
  final double targetAchievement;
  final double physiologicalResponse;
  final double subjectiveResponse;

  double get score => (completion.clamp(0, 100) * .30 +
          targetAchievement.clamp(0, 100) * .30 +
          physiologicalResponse.clamp(0, 100) * .20 +
          subjectiveResponse.clamp(0, 100) * .20)
      .clamp(0, 100);
}

class PolicyWorkout {
  const PolicyWorkout({
    required this.id,
    required this.title,
    required this.intensity,
    required this.durationMinutes,
    required this.targetLoad,
    this.intervalRepetitions,
  });

  final String id;
  final String title;
  final PolicyWorkoutIntensity intensity;
  final int durationMinutes;
  final double targetLoad;
  final int? intervalRepetitions;

  PolicyWorkout copyWith({
    String? title,
    PolicyWorkoutIntensity? intensity,
    int? durationMinutes,
    double? targetLoad,
    int? intervalRepetitions,
  }) =>
      PolicyWorkout(
        id: id,
        title: title ?? this.title,
        intensity: intensity ?? this.intensity,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        targetLoad: targetLoad ?? this.targetLoad,
        intervalRepetitions: intervalRepetitions ?? this.intervalRepetitions,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'intensity': intensity.name.toUpperCase(),
        'duration_minutes': durationMinutes,
        'target_load': targetLoad,
        if (intervalRepetitions != null)
          'interval_repetitions': intervalRepetitions,
      };
}

class AdaptiveTrainingPolicyInput {
  const AdaptiveTrainingPolicyInput({
    required this.plannedWorkout,
    required this.readiness,
    required this.fatigueRisk,
    required this.trainingProgress,
    required this.goalAlignment,
    this.hasRecentReadiness = true,
    this.hasRecentTrainingLoad = true,
    this.hasRecentWorkoutPerformance = false,
    this.hasRecentSleep = false,
    this.hasRecentHrv = false,
    this.hasRecentRestingHeartRate = false,
    this.hrvChangePercent,
    this.restingHeartRateDelta,
    this.sleepDeficitMinutes,
    this.fatigue = 3,
    this.soreness = 3,
    this.stress = 3,
    this.illnessSymptoms = false,
    this.injuryPain = false,
    this.acuteChronicLoadRatio,
    this.weeklyLoad,
    this.plannedWeeklyLoad,
    this.previousWeeklyLoad,
    this.consecutiveHardDays = 0,
    this.repeatedPoorRecoveryDays = 0,
    this.performanceDeclineDays = 0,
    this.lowTrainingLoadDays = 0,
    this.goodRecoveryDays = 0,
    this.missedWorkouts7Days = 0,
    this.similarFailedWorkouts = 0,
    this.strongSuccessfulWorkouts = 0,
    this.workoutSuccessScore,
    this.daysUntilPriorityEvent,
    this.isTaper = false,
    this.fitnessAppropriateForEvent = false,
    this.availableMinutes,
    this.ftpEvidenceCount = 0,
    this.estimatedFtpChangePercent = 0,
  });

  final PolicyWorkout plannedWorkout;
  final int readiness;
  final int fatigueRisk;
  final int trainingProgress;
  final int goalAlignment;
  final bool hasRecentReadiness;
  final bool hasRecentTrainingLoad;
  final bool hasRecentWorkoutPerformance;
  final bool hasRecentSleep;
  final bool hasRecentHrv;
  final bool hasRecentRestingHeartRate;
  final double? hrvChangePercent;
  final double? restingHeartRateDelta;
  final int? sleepDeficitMinutes;
  final int fatigue;
  final int soreness;
  final int stress;
  final bool illnessSymptoms;
  final bool injuryPain;
  final double? acuteChronicLoadRatio;
  final double? weeklyLoad;
  final double? plannedWeeklyLoad;
  final double? previousWeeklyLoad;
  final int consecutiveHardDays;
  final int repeatedPoorRecoveryDays;
  final int performanceDeclineDays;
  final int lowTrainingLoadDays;
  final int goodRecoveryDays;
  final int missedWorkouts7Days;
  final int similarFailedWorkouts;
  final int strongSuccessfulWorkouts;
  final double? workoutSuccessScore;
  final int? daysUntilPriorityEvent;
  final bool isTaper;
  final bool fitnessAppropriateForEvent;
  final int? availableMinutes;
  final int ftpEvidenceCount;
  final double estimatedFtpChangePercent;
}

class AdaptiveTrainingPolicyDecision {
  const AdaptiveTrainingPolicyDecision({
    required this.athleteState,
    required this.dataConfidence,
    required this.adaptationLevel,
    required this.decision,
    required this.plannedWorkout,
    required this.adaptedWorkout,
    required this.readiness,
    required this.fatigueRisk,
    required this.trainingProgress,
    required this.goalAlignment,
    required this.reasonCodes,
    required this.explanation,
    required this.next72hEffect,
    required this.planChangeRequired,
    required this.ftpReviewRequired,
    required this.confidence,
  });

  final PolicyAthleteState athleteState;
  final PolicyDataConfidence dataConfidence;
  final int adaptationLevel;
  final PolicyDecision decision;
  final PolicyWorkout plannedWorkout;
  final PolicyWorkout adaptedWorkout;
  final int readiness;
  final int fatigueRisk;
  final int trainingProgress;
  final int goalAlignment;
  final List<PolicyReasonCode> reasonCodes;
  final String explanation;
  final String next72hEffect;
  final bool planChangeRequired;
  final bool ftpReviewRequired;
  final double confidence;

  Map<String, Object?> toJson() => {
        'athlete_state': athleteState.name.toUpperCase(),
        'data_confidence': dataConfidence.name.toUpperCase(),
        'adaptation_level': adaptationLevel,
        'decision': _enumName(decision.name),
        'planned_workout': plannedWorkout.toJson(),
        'adapted_workout': adaptedWorkout.toJson(),
        'readiness': readiness,
        'fatigue_risk': fatigueRisk,
        'training_progress': trainingProgress,
        'goal_alignment': goalAlignment,
        'reason_codes': reasonCodes
            .map((reason) => _enumName(reason.name))
            .toList(growable: false),
        'explanation': explanation,
        'next_72h_effect': next72hEffect,
        'plan_change_required': planChangeRequired,
        'ftp_review_required': ftpReviewRequired,
        'confidence': confidence,
      };
}

class AdaptiveTrainingPolicy {
  const AdaptiveTrainingPolicy();

  AdaptiveTrainingPolicyDecision evaluate(AdaptiveTrainingPolicyInput input) {
    final dataConfidence = _dataConfidence(input);
    final reasons = _reasons(input);
    final athleteState = _athleteState(input);
    final ftpReview = input.ftpEvidenceCount >= 2 &&
        input.estimatedFtpChangePercent.abs() >= 3;
    if (ftpReview) {
      reasons.add(input.estimatedFtpChangePercent > 0
          ? PolicyReasonCode.ftpIncreaseLikely
          : PolicyReasonCode.ftpDecreaseLikely);
    }

    final choice = _choose(input, athleteState, dataConfidence, reasons);
    final confidence = switch (dataConfidence) {
      PolicyDataConfidence.high => .9,
      PolicyDataConfidence.medium => .7,
      PolicyDataConfidence.low => .45,
    };
    return AdaptiveTrainingPolicyDecision(
      athleteState: athleteState,
      dataConfidence: dataConfidence,
      adaptationLevel: choice.level,
      decision: choice.decision,
      plannedWorkout: input.plannedWorkout,
      adaptedWorkout: choice.workout,
      readiness: input.readiness.clamp(0, 100),
      fatigueRisk: input.fatigueRisk.clamp(0, 100),
      trainingProgress: input.trainingProgress.clamp(0, 100),
      goalAlignment: input.goalAlignment.clamp(0, 100),
      reasonCodes: List.unmodifiable(reasons.toSet()),
      explanation: choice.explanation,
      next72hEffect: choice.next72h,
      planChangeRequired: choice.level >= 2,
      ftpReviewRequired: ftpReview,
      confidence: confidence,
    );
  }

  PolicyDataConfidence _dataConfidence(AdaptiveTrainingPolicyInput input) {
    final independentSignals = [
      input.hasRecentReadiness,
      input.hasRecentTrainingLoad,
      input.hasRecentWorkoutPerformance,
      input.hasRecentSleep,
      input.hasRecentHrv,
      input.hasRecentRestingHeartRate,
    ].where((value) => value).length;
    if (independentSignals >= 5) return PolicyDataConfidence.high;
    if (independentSignals >= 2) return PolicyDataConfidence.medium;
    return PolicyDataConfidence.low;
  }

  PolicyAthleteState _athleteState(AdaptiveTrainingPolicyInput input) {
    if (input.illnessSymptoms || input.injuryPain) {
      return PolicyAthleteState.red;
    }
    if (input.performanceDeclineDays >= 3 &&
        (input.acuteChronicLoadRatio ?? 0) >= 1.3) {
      return PolicyAthleteState.overreaching;
    }
    if (input.performanceDeclineDays >= 7 && input.lowTrainingLoadDays >= 7) {
      return PolicyAthleteState.detraining;
    }
    if (input.goodRecoveryDays >= 7 &&
        input.lowTrainingLoadDays >= 7 &&
        input.trainingProgress < 60) {
      return PolicyAthleteState.undertrained;
    }
    if (input.isTaper &&
        (input.daysUntilPriorityEvent ?? 999) <= 14 &&
        input.fitnessAppropriateForEvent) {
      return PolicyAthleteState.peaking;
    }
    if (input.readiness < 45 ||
        input.repeatedPoorRecoveryDays >= 3 ||
        (input.acuteChronicLoadRatio ?? 0) > 1.5 ||
        input.fatigue >= 5 ||
        input.soreness >= 5) {
      return PolicyAthleteState.orange;
    }
    if (input.readiness < 60 ||
        input.fatigue >= 4 ||
        input.soreness >= 4 ||
        input.stress >= 4) {
      return PolicyAthleteState.yellow;
    }
    return PolicyAthleteState.green;
  }

  List<PolicyReasonCode> _reasons(AdaptiveTrainingPolicyInput input) => [
        input.readiness >= 75
            ? PolicyReasonCode.readinessHigh
            : input.readiness < 60
                ? PolicyReasonCode.readinessLow
                : PolicyReasonCode.readinessNormal,
        if ((input.hrvChangePercent ?? 0) <= -10)
          PolicyReasonCode.hrvSuppressed,
        if ((input.hrvChangePercent ?? 0) >= 10) PolicyReasonCode.hrvPositive,
        if ((input.restingHeartRateDelta ?? 0) >= 5)
          PolicyReasonCode.restingHrElevated,
        if ((input.sleepDeficitMinutes ?? 0) >= 60)
          PolicyReasonCode.sleepDeficit,
        if (input.fatigue >= 4) PolicyReasonCode.highFatigue,
        if (input.soreness >= 4) PolicyReasonCode.highSoreness,
        if (input.stress >= 4) PolicyReasonCode.highStress,
        if (input.illnessSymptoms) PolicyReasonCode.illnessFlag,
        if (input.injuryPain) PolicyReasonCode.injuryFlag,
        if ((input.acuteChronicLoadRatio ?? 0) > 1.5)
          PolicyReasonCode.acuteLoadHigh,
        if (input.lowTrainingLoadDays >= 7) PolicyReasonCode.trainingLoadLow,
        if ((input.workoutSuccessScore ?? 100) < 60)
          PolicyReasonCode.workoutFailed,
        if ((input.workoutSuccessScore ?? 0) >= 90)
          PolicyReasonCode.workoutExceeded,
        if (input.similarFailedWorkouts >= 3)
          PolicyReasonCode.repeatedWorkoutFailure,
        if (input.strongSuccessfulWorkouts >= 3)
          PolicyReasonCode.consistentStrongPerformance,
        if (input.missedWorkouts7Days == 1) PolicyReasonCode.missedWorkout,
        if (input.missedWorkouts7Days >= 2)
          PolicyReasonCode.multipleMissedWorkouts,
        if ((input.daysUntilPriorityEvent ?? 999) <= 21)
          PolicyReasonCode.eventProximity,
        if (input.isTaper) PolicyReasonCode.taperProtection,
        if (input.availableMinutes != null &&
            input.plannedWorkout.durationMinutes > input.availableMinutes!)
          PolicyReasonCode.scheduleConstraint,
      ];

  ({
    int level,
    PolicyDecision decision,
    PolicyWorkout workout,
    String explanation,
    String next72h,
  }) _choose(
    AdaptiveTrainingPolicyInput input,
    PolicyAthleteState state,
    PolicyDataConfidence confidence,
    List<PolicyReasonCode> reasons,
  ) {
    final planned = input.plannedWorkout;
    if (input.illnessSymptoms || input.injuryPain) {
      reasons.add(PolicyReasonCode.recoveryRequired);
      return (
        level: 1,
        decision: PolicyDecision.rest,
        workout: _rest(planned),
        explanation:
            'Athlete-reported illness or injury risk overrides wearable and readiness data, so no training is prescribed today.',
        next72h:
            'Reassess symptoms daily and resume only with an appropriately conservative session.',
      );
    }

    if (input.availableMinutes != null && input.availableMinutes! <= 0) {
      return (
        level: 1,
        decision: PolicyDecision.rest,
        workout: _rest(planned),
        explanation:
            'The athlete is unavailable today, so no training is prescribed or moved forward as hidden load.',
        next72h: 'Keep the remaining plan unchanged and reassess tomorrow.',
      );
    }

    if (input.availableMinutes != null &&
        planned.durationMinutes > input.availableMinutes!) {
      final scale = input.availableMinutes! / planned.durationMinutes;
      return (
        level: 1,
        decision: PolicyDecision.reduceVolume,
        workout: planned.copyWith(
          durationMinutes: input.availableMinutes,
          targetLoad: planned.targetLoad * scale,
          title: '${planned.title} · availability adjusted',
        ),
        explanation:
            'The session is shortened to fit the athlete’s stated availability without changing its purpose.',
        next72h:
            'Keep the remaining week unchanged; do not repay the removed volume.',
      );
    }

    final blockEvidence = input.repeatedPoorRecoveryDays >= 14 ||
        input.similarFailedWorkouts >= 3 ||
        input.performanceDeclineDays >= 14;
    if (blockEvidence) {
      reasons.add(PolicyReasonCode.deloadRequired);
      return (
        level: 3,
        decision: PolicyDecision.rebuildBlock,
        workout: _reduce(planned, volume: .8, intensity: true),
        explanation:
            'Multi-week recovery or performance evidence justifies rebuilding the training block while preserving the goal.',
        next72h:
            'Reduce immediate cost, protect recovery spacing and regenerate the next 2–4 weeks.',
      );
    }

    final microcycleEvidence = input.repeatedPoorRecoveryDays >= 3 ||
        input.missedWorkouts7Days >= 2 ||
        state == PolicyAthleteState.overreaching;
    if (microcycleEvidence) {
      reasons.add(PolicyReasonCode.deloadRequired);
      return (
        level: 2,
        decision: PolicyDecision.rebuildMicrocycle,
        workout: planned.intensity == PolicyWorkoutIntensity.high
            ? _endurance(planned)
            : _reduce(planned, volume: .8),
        explanation:
            'Several days of fatigue, missed training or excessive load justify reorganising the next 3–7 days rather than moving missed work forward.',
        next72h:
            'Remove optional load, separate hard sessions and preserve the next key workout only if recovery normalises.',
      );
    }

    if (input.consecutiveHardDays >= 1 &&
        planned.intensity == PolicyWorkoutIntensity.high) {
      reasons.add(PolicyReasonCode.recoveryRequired);
      return (
        level: 1,
        decision: PolicyDecision.changeToEndurance,
        workout: _endurance(planned),
        explanation:
            'A consecutive high-intensity day would compromise recovery spacing, so today retains useful aerobic training at lower cost.',
        next72h:
            'Reassess readiness before restoring the next demanding session.',
      );
    }

    if (state == PolicyAthleteState.orange || input.readiness < 45) {
      reasons.add(PolicyReasonCode.recoveryRequired);
      final high = planned.intensity == PolicyWorkoutIntensity.high;
      return (
        level: 1,
        decision: high
            ? PolicyDecision.changeToEndurance
            : PolicyDecision.reduceVolumeAndIntensity,
        workout: high
            ? _endurance(planned)
            : _reduce(planned, volume: .7, intensity: true),
        explanation:
            'Multiple recovery or fatigue signals support reducing training cost, using the smallest safe change for the planned session.',
        next72h:
            'Keep recovery easy and restore load only after the short-term trend improves.',
      );
    }

    if (state == PolicyAthleteState.yellow || input.readiness < 60) {
      return (
        level: 1,
        decision: planned.intensity == PolicyWorkoutIntensity.high
            ? PolicyDecision.reduceIntensity
            : PolicyDecision.reduceVolume,
        workout: _reduce(
          planned,
          volume: planned.intensity == PolicyWorkoutIntensity.high ? .9 : .8,
          intensity: planned.intensity == PolicyWorkoutIntensity.high,
        ),
        explanation:
            'Readiness is reduced with supporting fatigue evidence, so session cost is trimmed without removing useful training.',
        next72h:
            'The wider plan stays intact unless reduced recovery persists for three days.',
      );
    }

    final progressionEvidence = input.strongSuccessfulWorkouts >= 3 &&
        input.goodRecoveryDays >= 3 &&
        confidence != PolicyDataConfidence.low &&
        !input.isTaper;
    if (progressionEvidence) {
      reasons.add(PolicyReasonCode.progressionAppropriate);
      return (
        level: 1,
        decision: PolicyDecision.progress,
        workout: planned.copyWith(
          durationMinutes: (planned.durationMinutes * 1.05).round(),
          targetLoad: planned.targetLoad * 1.05,
          title: '${planned.title} · small progression',
        ),
        explanation:
            'Several successful sessions with normal recovery support a single 5% progression; one good readiness day alone would not.',
        next72h:
            'Monitor completion and recovery before making another progression.',
      );
    }

    return (
      level: 0,
      decision: PolicyDecision.keep,
      workout: planned,
      explanation: input.isTaper
          ? 'The planned session already protects taper freshness; no extra work is added near the event.'
          : 'Available recovery, training and performance evidence does not justify changing the planned workout.',
      next72h:
          'Continue the plan and reassess after the workout using objective and subjective response.',
    );
  }

  PolicyWorkout _reduce(
    PolicyWorkout workout, {
    required double volume,
    bool intensity = false,
  }) =>
      workout.copyWith(
        title: '${workout.title} · reduced',
        durationMinutes: (workout.durationMinutes * volume).round(),
        targetLoad: workout.targetLoad * volume * (intensity ? .9 : 1),
        intensity: intensity && workout.intensity == PolicyWorkoutIntensity.high
            ? PolicyWorkoutIntensity.moderate
            : workout.intensity,
        intervalRepetitions: workout.intervalRepetitions == null
            ? null
            : (workout.intervalRepetitions! * volume).round().clamp(1, 99),
      );

  PolicyWorkout _endurance(PolicyWorkout workout) => workout.copyWith(
        title: '${workout.title} · endurance replacement',
        intensity: PolicyWorkoutIntensity.endurance,
        durationMinutes: (workout.durationMinutes * .8).round(),
        targetLoad: workout.targetLoad * .6,
        intervalRepetitions: 1,
      );

  PolicyWorkout _rest(PolicyWorkout workout) => workout.copyWith(
        title: 'Rest and reassess',
        intensity: PolicyWorkoutIntensity.rest,
        durationMinutes: 0,
        targetLoad: 0,
        intervalRepetitions: 1,
      );
}

String _enumName(String value) => value
    .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'), (match) => '${match[1]}_${match[2]}')
    .toUpperCase();
