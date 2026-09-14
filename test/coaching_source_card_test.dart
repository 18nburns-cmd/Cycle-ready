import 'package:cycle_ready/src/features/dashboard/presentation/coaching_source_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase in <(CoachingSourceState, String)>[
    (CoachingSourceState.checking, "Checking today's coaching"),
    (CoachingSourceState.offlineFallback, 'Using on-phone coaching'),
  ]) {
    testWidgets('shows ${testCase.$1.name} state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CoachingSourceCard(state: testCase.$1)),
      );

      expect(find.text(testCase.$2), findsOneWidget);
    });
  }

  testWidgets('does not show a card for normal authoritative coaching',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoachingSourceCard(state: CoachingSourceState.authoritative),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text("Today's coaching is synced"), findsNothing);
  });
}
