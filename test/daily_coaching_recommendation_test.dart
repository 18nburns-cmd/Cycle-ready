import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the authoritative selected workout', () {
    final recommendation = DailyCoachingRecommendation.fromJson({
      'coaching_date': '2026-09-08',
      'model_version': 'daily-coaching-v1',
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
}
