import 'package:cycle_ready/src/features/coaching/application/workout_browser_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/unplanned_workout_choices.dart';
import 'package:cycle_ready/src/features/coaching/presentation/workout_browser_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UnplannedWorkoutChoice candidate(
  String family,
  int minutes, {
  bool safe = true,
}) =>
    UnplannedWorkoutChoice(
      family: family,
      type: SessionType.endurance,
      title: '$family $minutes',
      durationMinutes: minutes,
      targetLoad: 35,
      prescription: 'Structured workout',
      reason: 'Matched to current evidence',
      confidence: .8,
      suitabilityScore: 75,
      rejectionReasons: safe ? const [] : const ['Unsafe today'],
    );

class BrowserHarness extends StatefulWidget {
  const BrowserHarness({required this.candidates, super.key});
  final List<UnplannedWorkoutChoice> candidates;

  @override
  State<BrowserHarness> createState() => _BrowserHarnessState();
}

class _BrowserHarnessState extends State<BrowserHarness> {
  late final WorkoutBrowserController controller =
      WorkoutBrowserController(widget.candidates);
  String? selected;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              WorkoutBrowserFilters(
                state: controller.state,
                onFamilyChanged: (family) => setState(
                  () => controller.filterByFamily(family),
                ),
                onDurationChanged: (duration) => setState(
                  () => controller.filterByDuration(duration),
                ),
              ),
              for (final option in controller.state.visibleCandidates)
                TextButton(
                  onPressed: option.isEligible
                      ? () => setState(() {
                            selected = controller.select(option)?.title;
                          })
                      : null,
                  child: Text(option.title),
                ),
              if (selected != null) Text('Selected $selected'),
            ],
          ),
        ),
      );
}

void main() {
  testWidgets('browses and filters workout families and duration',
      (tester) async {
    await tester.pumpWidget(BrowserHarness(candidates: [
      candidate('Endurance', 40),
      candidate('Endurance', 90),
      candidate('Threshold', 60),
    ]));

    await tester.tap(find.byKey(const Key('workout-family-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endurance').last);
    await tester.pumpAndSettle();
    expect(find.text('Threshold 60'), findsNothing);

    await tester.tap(find.text('Up to 45 min'));
    await tester.pumpAndSettle();
    expect(find.text('Endurance 40'), findsOneWidget);
    expect(find.text('Endurance 90'), findsNothing);
  });

  testWidgets('selects a safe workout and disables a rejected one',
      (tester) async {
    await tester.pumpWidget(BrowserHarness(candidates: [
      candidate('Endurance', 40),
      candidate('Threshold', 60, safe: false),
    ]));

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Threshold 60'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Endurance 40'));
    await tester.pump();
    expect(find.text('Selected Endurance 40'), findsOneWidget);
  });
}
