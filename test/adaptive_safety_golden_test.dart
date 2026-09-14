import 'dart:convert';
import 'dart:io';

import 'package:cycle_ready/src/features/coaching/domain/adaptive_training_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart safety matches the shared server golden scenarios', () {
    final scenarios = (jsonDecode(File(
      'test/fixtures/adaptive_safety_scenarios.json',
    ).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    for (final scenario in scenarios) {
      final result = const AdaptiveTrainingPolicy().evaluate(
        AdaptiveTrainingPolicyInput(
          plannedWorkout: const PolicyWorkout(
            id: 'threshold-1',
            title: 'Threshold session',
            intensity: PolicyWorkoutIntensity.high,
            durationMinutes: 70,
            targetLoad: 80,
          ),
          readiness: scenario['athlete_state'] == 'RED' ? 20 : 80,
          fatigueRisk: 25,
          trainingProgress: 70,
          goalAlignment: 90,
          illnessSymptoms: scenario['illness'] as bool,
          injuryPain: scenario['injury'] as bool,
          availableMinutes: scenario['available_minutes'] as int,
        ),
      );
      final outcome =
          result.decision == PolicyDecision.rest ? 'REST' : 'CONTINUE';
      expect(outcome, scenario['expected'], reason: scenario['name'] as String);
    }
  });

  test('server policy imports the production shared safety gate', () {
    final source = File(
      'supabase/functions/process-adaptive-decision/index.ts',
    ).readAsStringSync();
    expect(source, contains("from '../_shared/adaptive-safety.ts'"));
    expect(source, contains('evaluateAdaptiveSafety({'));
  });
}
