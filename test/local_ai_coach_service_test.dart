import 'package:cycle_ready/src/features/coaching/application/local_ai_coach_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates structured coach JSON', () {
    final response = LocalCoachResponse.parse('''
      {"headline":"Recover today","summary":"Fatigue is high.",
      "keyFactors":["Low HRV"],"recommendation":"Ride easily",
      "confidence":"high"}
    ''');
    expect(response.headline, 'Recover today');
    expect(response.keyFactors, ['Low HRV']);
  });

  test('falls back safely when structured generation fails', () {
    final response = LocalCoachResponse.parse('Keep today easy.');
    expect(response.confidence, 'unstructured');
    expect(response.summary, 'Keep today easy.');
  });

  test('builds a conversational task-specific prompt', () {
    final prompt = buildLocalCoachPrompt(
      task: "Today's Recommendation",
      data: const {
        'readiness': {'score': 58}
      },
    );
    expect(prompt, contains('what the rider should do today'));
    expect(prompt, contains('concise, personal and natural'));
    expect(prompt, isNot(contains('Application-calculated data:')));
  });
}
