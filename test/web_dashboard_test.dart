import 'package:cycle_ready/main_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('wide web dashboard uses a persistent navigation rail',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: CycleReadyWebApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Secure sync required'), findsOneWidget);

    await tester.tap(find.text('Performance').first);
    await tester.pumpAndSettle();
    expect(
        find.text('Fitness, fatigue, form, power curve and ride analysis '
            'will appear here once cloud sync is connected.'),
        findsOneWidget);
  });

  testWidgets('compact web dashboard uses bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: CycleReadyWebApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Cloud not configured'), findsOneWidget);
  });
}
