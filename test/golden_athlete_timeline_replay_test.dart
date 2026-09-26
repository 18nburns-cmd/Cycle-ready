import 'dart:convert';
import 'dart:io';

import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/golden_athlete_timelines.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final timelines = (fixture['timelines'] as List).cast<Map<String, dynamic>>();

  test('Dart coaching replays every golden athlete day safely', () {
    for (final timeline in timelines) {
      final isTaper = timeline['phase'] == 'TAPER';
      final days = (timeline['days'] as List).cast<Map<String, dynamic>>();
      for (final day in days) {
        final planned = day['planned'] as Map<String, dynamic>;
        final evidence = day['evidence'] as Map<String, dynamic>;
        final expected = day['expected'] as Map<String, dynamic>;
        final decision = const AdaptiveTrainingPolicy().evaluate(
          AdaptiveTrainingPolicyInput(
            plannedWorkout: PolicyWorkout(
              id: '${timeline['id']}:${day['date']}',
              title: '${planned['family']} ${planned['duration_minutes']}',
              intensity: _intensity('${planned['family']}'),
              durationMinutes: planned['duration_minutes'] as int,
              targetLoad: (planned['target_load'] as num).toDouble(),
            ),
            readiness: evidence['readiness'] as int,
            fatigueRisk: evidence['fatigue_risk'] as int,
            trainingProgress: 60,
            goalAlignment: 75,
            hasRecentReadiness: true,
            hasRecentTrainingLoad: evidence['acute_chronic_load_ratio'] != null,
            hasRecentSleep: evidence['sleep_deficit_minutes'] != null,
            hasRecentHrv: evidence['hrv_change_percent'] != null,
            hasRecentRestingHeartRate: evidence['resting_hr_delta'] != null,
            hrvChangePercent:
                (evidence['hrv_change_percent'] as num?)?.toDouble(),
            restingHeartRateDelta:
                (evidence['resting_hr_delta'] as num?)?.toDouble(),
            sleepDeficitMinutes: evidence['sleep_deficit_minutes'] as int?,
            fatigue: evidence['fatigue'] as int,
            soreness: evidence['soreness'] as int,
            stress: evidence['stress'] as int,
            illnessSymptoms: evidence['illness_symptoms'] as bool,
            injuryPain: evidence['injury_pain'] as bool,
            acuteChronicLoadRatio:
                (evidence['acute_chronic_load_ratio'] as num?)?.toDouble(),
            isTaper: isTaper,
            daysUntilPriorityEvent: isTaper ? 7 : null,
            fitnessAppropriateForEvent: isTaper,
            availableMinutes: evidence['available_minutes'] as int,
          ),
        );
        final action = _action(decision.decision);
        expect(
          (expected['allowed_actions'] as List).contains(action),
          isTrue,
          reason: '${timeline['id']} ${day['date']}: $action',
        );
        if (expected['hard_session_allowed'] == false) {
          expect(
            decision.adaptedWorkout.intensity,
            isNot(PolicyWorkoutIntensity.high),
            reason: '${timeline['id']} ${day['date']}',
          );
        }
      }
    }
  });

  test('server replay imports the same fixture and production safety gate', () {
    final replay = File(
      'supabase/functions/_shared/golden-athlete-timelines_test.ts',
    ).readAsStringSync();
    final engine = File(
      'supabase/functions/process-adaptive-decision/index.ts',
    ).readAsStringSync();
    expect(replay, contains('golden_athlete_timelines.json'));
    expect(replay, contains('evaluateAdaptiveSafety'));
    expect(engine, contains("from '../_shared/adaptive-safety.ts'"));
  });
}

PolicyWorkoutIntensity _intensity(String family) => switch (family) {
      'rest' => PolicyWorkoutIntensity.rest,
      'recovery' => PolicyWorkoutIntensity.recovery,
      'endurance' => PolicyWorkoutIntensity.endurance,
      'tempo' || 'sweet_spot' => PolicyWorkoutIntensity.moderate,
      _ => PolicyWorkoutIntensity.high,
    };

String _action(PolicyDecision decision) => switch (decision) {
      PolicyDecision.keep || PolicyDecision.progress => 'KEEP',
      PolicyDecision.rest => 'REST',
      PolicyDecision.reduceVolume ||
      PolicyDecision.reduceIntensity ||
      PolicyDecision.reduceVolumeAndIntensity =>
        'REDUCE',
      _ => 'MODIFY',
    };
