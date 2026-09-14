import 'package:cycle_ready/src/features/cloud_sync/presentation/web_today_coaching_card.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the authoritative workout and explanation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WebTodayCoachingCard(
        recommendation: DailyCoachingRecommendation(
          date: DateTime(2026, 9, 8),
          decision: 'KEEP',
          explanation: 'Recovery supports the planned aerobic work.',
          confidence: .88,
          modelVersion: 'daily-coaching-v1',
          workout: const DailyCoachingWorkout(
            title: 'Aerobic endurance',
            family: 'endurance',
            durationMinutes: 60,
            targetLoad: 45,
          ),
        ),
      ),
    ));

    expect(find.text('Aerobic endurance'), findsOneWidget);
    expect(find.text('60 min • 45 load'), findsOneWidget);
    expect(find.text('Recovery supports the planned aerobic work.'),
        findsOneWidget);
    expect(find.text('Confidence 88%'), findsOneWidget);
  });

  testWidgets('shows an authoritative rest day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WebTodayCoachingCard(
        recommendation: DailyCoachingRecommendation(
          date: DateTime(2026, 9, 8),
          decision: 'REST',
          explanation: 'Rest is the safest choice.',
          confidence: .9,
          modelVersion: 'daily-coaching-v1',
        ),
      ),
    ));

    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('No riding prescribed'), findsOneWidget);
  });
}
