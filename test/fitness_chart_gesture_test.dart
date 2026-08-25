import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/presentation/fitness_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dragging across fitness chart does not change parent page',
      (tester) async {
    final start = DateTime(2026, 8, 1);
    final points = List.generate(
      28,
      (index) => FitnessPoint(
        date: start.add(Duration(days: index)),
        fitness: 30 + index / 2,
        fatigue: 32 + index / 3,
        form: -2 + index / 6,
        load: index.isEven ? 50 : 0,
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: PageView(children: [
        Scaffold(
          body: Column(children: [
            const Text('Rides page'),
            FitnessChart(points: points, chartHeight: 240),
          ]),
        ),
        const Scaffold(body: Text('Next tab')),
      ]),
    ));

    final chart = find.byType(CustomPaint).first;
    await tester.drag(chart, const Offset(-240, 0));
    await tester.pumpAndSettle();

    expect(find.text('Rides page'), findsOneWidget);
    expect(find.text('Next tab'), findsNothing);
  });
}
