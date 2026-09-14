import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/presentation/activities_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not interrupt the rides dashboard with duplicate warnings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final start = DateTime.now().subtract(const Duration(hours: 2));
    for (final ride in [
      (
        id: 'health-ride',
        source: 'health_connect',
        start: start,
        duration: 3600,
        distance: 30000.0,
      ),
      (
        id: 'intervals-ride',
        source: 'intervals_icu',
        start: start.add(const Duration(minutes: 1)),
        duration: 3580,
        distance: 29900.0,
      ),
    ]) {
      await database.saveActivity(
        ActivitiesCompanion.insert(
          id: ride.id,
          source: ride.source,
          startedAt: ride.start,
          durationSeconds: ride.duration,
          distanceMetres: ride.distance,
          averagePower: const Value(200),
          trainingLoad: const Value(65),
        ),
        const [],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ActivitiesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('possible duplicate'), findsNothing);
    expect(await database.getActivities(), hasLength(2));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}
