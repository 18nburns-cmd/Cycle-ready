import 'package:cycle_ready/src/features/activities/domain/session_outcome_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SessionOutcomePolicy();

  test('achieved and absorbed sessions progress only with comparable history',
      () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.threshold),
      evidence: _evidence(
        intervalCompletionPercent: 80,
        powerTargetAchievementPercent: 80,
        intervalQualityPercent: 80,
        comparableAchievedSessions: 2,
      ),
    );

    expect(result.sessionOutcome, SessionOutcome.achieved);
    expect(result.progressionAllowed, isTrue);
    expect(result.nextSessionAction, NextSessionAction.progress);
    expect(result.toJson()['session_outcome'], 'ACHIEVED');
  });

  test('one excellent workout is held instead of automatically progressed', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.threshold),
      evidence: _evidence(comparableAchievedSessions: 0),
    );

    expect(result.adaptationAchieved, isTrue);
    expect(result.progressionAllowed, isFalse);
    expect(result.nextSessionAction, NextSessionAction.hold);
  });

  test('successful stimulus with excessive recovery cost is high cost', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.vo2Max),
      evidence: _evidence(
        fatigue: 5,
        soreness: 5,
        readinessDrop: 35,
        nextDayHrvChangePercent: -15,
      ),
    );

    expect(result.sessionOutcome, SessionOutcome.achievedHighCost);
    expect(result.progressionAllowed, isFalse);
    expect(result.nextSessionAction, NextSessionAction.changeToRecovery);
  });

  test('valid endurance data produces durability and Pw:Hr output', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.longEndurance),
      evidence: _evidence(
        decouplingIsValid: true,
        pwHrDecouplingPercent: 4,
        powerFadePercent: 3,
        cadenceStabilityPercent: 95,
        rpeDrift: 1,
      ),
    );

    expect(result.durabilityScore, greaterThan(80));
    expect(result.pwHrDecouplingPercent, 4);
  });

  test('invalid decoupling is excluded rather than treated as failure', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.endurance),
      evidence: _evidence(
        decouplingIsValid: false,
        pwHrDecouplingPercent: 12,
      ),
    );

    expect(result.pwHrDecouplingPercent, isNull);
    expect(result.outcomeReasons, contains(contains('excluded')));
  });

  test('failed session identifies context before changing FTP', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.threshold),
      evidence: _evidence(
        intervalCompletionPercent: 40,
        powerTargetAchievementPercent: 45,
        intervalQualityPercent: 40,
        completedDurationMinutes: 30,
        fatigue: 5,
        recoveryWasNormal: false,
      ),
    );

    expect(result.sessionOutcome, SessionOutcome.notAchieved);
    expect(result.possibleFailureCauses, contains(SessionFailureCause.fatigue));
    expect(
      result.possibleFailureCauses,
      isNot(contains(SessionFailureCause.incorrectFtp)),
    );
  });

  test('repeated failure with normal recovery rebuilds week and reviews dose',
      () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.threshold),
      evidence: _evidence(
        intervalCompletionPercent: 45,
        powerTargetAchievementPercent: 50,
        intervalQualityPercent: 45,
        comparableFailedSessions: 3,
      ),
    );

    expect(result.planChangeRequired, isTrue);
    expect(result.nextSessionAction, NextSessionAction.rebuildWeek);
    expect(
      result.possibleFailureCauses,
      contains(SessionFailureCause.incorrectFtp),
    );
  });

  test('recovery rides are never progressed into harder work', () {
    final result = policy.evaluate(
      purpose: _purpose(CoachingSessionType.recovery),
      evidence: _evidence(
        rpe: 2,
        expectedRpe: 2,
        comparableAchievedSessions: 5,
      ),
    );

    expect(result.nextSessionAction, NextSessionAction.hold);
  });
}

SessionPurpose _purpose(CoachingSessionType type) => SessionPurpose(
      sessionType: type,
      primaryAdaptation: type == CoachingSessionType.threshold
          ? 'Sustainable threshold power'
          : 'Aerobic durability',
      secondaryAdaptation: 'Pacing',
      plannedDurationMinutes: 60,
      targetIntensity: 'Purpose-specific power range',
      keyIntervals: const ['Main work'],
      successMetrics: const ['Complete prescribed work'],
      progressionIfSuccessful: 'Progress one variable by 3–8%.',
      actionIfUnsuccessful: 'Identify cause before changing prescription.',
    );

SessionOutcomeEvidence _evidence({
  int completedDurationMinutes = 60,
  double intervalCompletionPercent = 85,
  double powerTargetAchievementPercent = 85,
  double intervalQualityPercent = 85,
  int fatigue = 2,
  int soreness = 2,
  double readinessDrop = 5,
  double nextDayHrvChangePercent = 0,
  bool recoveryWasNormal = true,
  int comparableAchievedSessions = 0,
  int comparableFailedSessions = 0,
  bool decouplingIsValid = false,
  double? pwHrDecouplingPercent,
  double? powerFadePercent,
  double? cadenceStabilityPercent,
  double? rpeDrift,
  double rpe = 7,
  double expectedRpe = 7,
}) =>
    SessionOutcomeEvidence(
      completedDurationMinutes: completedDurationMinutes,
      intervalCompletionPercent: intervalCompletionPercent,
      powerTargetAchievementPercent: powerTargetAchievementPercent,
      intervalQualityPercent: intervalQualityPercent,
      fatigue: fatigue,
      soreness: soreness,
      readinessDrop: readinessDrop,
      nextDayHrvChangePercent: nextDayHrvChangePercent,
      recoveryWasNormal: recoveryWasNormal,
      comparableAchievedSessions: comparableAchievedSessions,
      comparableFailedSessions: comparableFailedSessions,
      decouplingIsValid: decouplingIsValid,
      pwHrDecouplingPercent: pwHrDecouplingPercent,
      powerFadePercent: powerFadePercent,
      cadenceStabilityPercent: cadenceStabilityPercent,
      rpeDrift: rpeDrift,
      rpe: rpe,
      expectedRpe: expectedRpe,
    );
