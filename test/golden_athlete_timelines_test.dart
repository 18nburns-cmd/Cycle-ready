import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/golden_athlete_timelines.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final timelines = (fixture['timelines'] as List).cast<Map<String, dynamic>>();

  test('covers every required anonymized athlete scenario', () {
    expect(fixture['schema_version'], '1.0');
    expect(
      timelines.map((timeline) => timeline['id']).toSet(),
      {
        'normal_training',
        'overload',
        'illness',
        'taper',
        'missing_data',
      },
    );
    expect(jsonEncode(fixture), isNot(contains('@')));
    expect(jsonEncode(fixture).toLowerCase(), isNot(contains('18nburns')));
  });

  test('each timeline is chronological and carries replayable evidence', () {
    for (final timeline in timelines) {
      final days = (timeline['days'] as List).cast<Map<String, dynamic>>();
      expect(days.length, greaterThanOrEqualTo(5), reason: '${timeline['id']}');
      final dates =
          days.map((day) => DateTime.parse(day['date'] as String)).toList();
      expect(dates.toSet().length, dates.length, reason: '${timeline['id']}');
      expect([...dates]..sort(), dates, reason: '${timeline['id']}');

      for (final day in days) {
        final planned = day['planned'] as Map<String, dynamic>;
        final evidence = day['evidence'] as Map<String, dynamic>;
        final expected = day['expected'] as Map<String, dynamic>;
        expect(planned['family'], isA<String>());
        expect(planned['duration_minutes'], isA<int>());
        expect(planned['target_load'], isA<int>());
        expect(evidence['readiness'], isA<int>());
        expect(evidence['illness_symptoms'], isA<bool>());
        expect(evidence['injury_pain'], isA<bool>());
        expect(evidence['available_minutes'], isA<int>());
        expect(expected['allowed_actions'], isNotEmpty);
        expect(expected['hard_session_allowed'], isA<bool>());
      }
    }
  });

  test('missing-data timeline contains explicit null evidence', () {
    final missing = timelines.singleWhere(
      (timeline) => timeline['id'] == 'missing_data',
    );
    final days = (missing['days'] as List).cast<Map<String, dynamic>>();
    expect(
      days.any((day) =>
          (day['evidence'] as Map<String, dynamic>)['hrv_change_percent'] ==
          null),
      isTrue,
    );
  });
}
