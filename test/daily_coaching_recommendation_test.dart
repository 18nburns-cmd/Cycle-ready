import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the authoritative selected workout', () {
    final recommendation = DailyCoachingRecommendation.fromJson({
      'coaching_date': '2026-09-08',
      'model_version': 'daily-coaching-v1',
      'generated_at': '2026-09-08T05:00:00Z',
      'recommendation': {
        'decision': 'MODIFY',
        'explanation': 'Reduced duration after poor sleep.',
        'confidence': .82,
        'selected_workout': {
          'title': 'Short aerobic endurance',
          'family': 'endurance',
          'duration_minutes': 45,
          'target_load': 32,
        },
      },
    });

    expect(recommendation.decision, 'MODIFY');
    expect(recommendation.confidence, .82);
    expect(recommendation.workout?.title, 'Short aerobic endurance');
    expect(recommendation.workout?.durationMinutes, 45);
    expect(recommendation.workout?.targetLoad, 32);
    expect(
      recommendation.generatedAt,
      DateTime.parse('2026-09-08T05:00:00Z'),
    );
  });

  test('accepts an authoritative rest recommendation without a workout', () {
    final recommendation = DailyCoachingRecommendation.fromJson({
      'coaching_date': '2026-09-08',
      'model_version': 'daily-coaching-v1',
      'recommendation': {
        'decision': 'REST',
        'explanation': 'Recovery is the priority today.',
        'selected_workout': null,
      },
    });

    expect(recommendation.decision, 'REST');
    expect(recommendation.workout, isNull);
    expect(recommendation.confidence, .45);
  });

  test('parses the direct Edge Function response schema', () {
    final recommendation = DailyCoachingRecommendation.fromOutputJson({
      'coaching_date': '2026-09-10',
      'decision': 'KEEP',
      'explanation': 'Recovery supports the planned session.',
      'confidence': .87,
      'model_version': 'daily-coaching-orchestrator-v1.0.0',
      'selected_workout': {
        'title': 'Endurance 60',
        'family': 'endurance',
        'duration_minutes': 60,
        'target_load': 48,
      },
    });

    expect(recommendation.decision, 'KEEP');
    expect(recommendation.workout?.durationMinutes, 60);
    expect(recommendation.confidence, .87);
  });

  test('detects when a stored recommendation differs from the calendar', () {
    final recommendation = DailyCoachingRecommendation(
      date: DateTime(2026, 9, 21),
      decision: 'MODIFY',
      explanation: 'Use the closest safe dose.',
      confidence: .8,
      modelVersion: 'test-v1',
      workout: const DailyCoachingWorkout(
        title: 'Endurance · 45 min',
        family: 'endurance',
        durationMinutes: 45,
        targetLoad: 19,
      ),
    );

    expect(
      dailyCoachingRecommendationMatchesPlan(
        recommendation: recommendation,
        plannedSessionType: 'recovery',
        plannedTitle: 'Recovery · 35 min',
        plannedDurationMinutes: 35,
        plannedTargetLoad: 15,
      ),
      isFalse,
    );
    expect(
      dailyCoachingRecommendationMatchesPlan(
        recommendation: recommendation,
        plannedSessionType: 'endurance',
        plannedTitle: 'Endurance · 45 min',
        plannedDurationMinutes: 45,
        plannedTargetLoad: 19,
      ),
      isTrue,
    );
  });

  test('matches an authoritative rest decision only to a calendar rest day',
      () {
    final recommendation = DailyCoachingRecommendation(
      date: DateTime(2026, 9, 21),
      decision: 'REST',
      explanation: 'Rest is required.',
      confidence: .9,
      modelVersion: 'test-v1',
    );

    expect(
      dailyCoachingRecommendationMatchesPlan(
        recommendation: recommendation,
        plannedSessionType: 'rest',
        plannedTitle: 'Rest day',
        plannedDurationMinutes: 0,
        plannedTargetLoad: 0,
      ),
      isTrue,
    );
    expect(
      dailyCoachingRecommendationMatchesPlan(
        recommendation: recommendation,
        plannedSessionType: 'recovery',
        plannedTitle: 'Recovery · 30 min',
        plannedDurationMinutes: 30,
        plannedTargetLoad: 10,
      ),
      isFalse,
    );
  });
}
