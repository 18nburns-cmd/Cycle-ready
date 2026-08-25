import 'package:cycle_ready/src/features/strength/domain/strength_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful weighted sets trigger a conservative increase', () {
    final result = calculateStrengthProgression('squat', [
      for (var set = 0; set < 3; set++)
        StrengthSetPerformance(
          sessionId: 2,
          completedAt: DateTime(2026, 7, 30),
          weightKg: 40,
          reps: 8,
          targetReps: 8,
        ),
    ]);
    expect(result!.action, ProgressionAction.increase);
    expect(result.suggestedWeightKg, 42.5);
  });

  test('substantially missed reps trigger a small reduction', () {
    final result = calculateStrengthProgression('deadlift', [
      StrengthSetPerformance(
        sessionId: 3,
        completedAt: DateTime(2026, 7, 30),
        weightKg: 60,
        reps: 5,
        targetReps: 8,
      ),
    ]);
    expect(result!.action, ProgressionAction.reduce);
    expect(result.suggestedWeightKg, 57);
  });

  test('bodyweight movements progress by repetitions', () {
    final result = calculateStrengthProgression('push_up', [
      StrengthSetPerformance(
        sessionId: 4,
        completedAt: DateTime(2026, 7, 30),
        weightKg: 0,
        reps: 10,
        targetReps: 10,
      ),
    ]);
    expect(result!.action, ProgressionAction.addReps);
    expect(result.suggestedReps, 11);
  });
}
