import 'package:cycle_ready/main_web.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_account.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/relational_coaching_data.dart';
import 'package:cycle_ready/src/features/coaching/application/daily_coaching_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'authenticated relational data survives wide and compact navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _SmokeRelationalRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        cloudConfigProvider.overrideWithValue(const CloudConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'synthetic-publishable-key',
        )),
        cloudAccountProvider.overrideWith(
          (ref) => Stream.value(const CloudAccount(
            id: 'synthetic-user',
            email: 'smoke@example.invalid',
          )),
        ),
        relationalCoachingRepositoryProvider.overrideWithValue(repository),
        todayDailyCoachingRecommendationProvider.overrideWith(
          (ref) async => null,
        ),
      ],
      child: const CycleReadyWebApp(),
    ));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 1);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('smoke@example.invalid'), findsOneWidget);
    expect(find.text('246 W'), findsOneWidget);
    expect(find.textContaining('Synthetic endurance ride'), findsNothing);

    await tester.tap(find.text('Performance').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Synthetic endurance ride'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Training calendar'), findsOneWidget);
    expect(find.text('Synthetic planned endurance'), findsAtLeast(1));
    expect(repository.fetchCount, 1,
        reason: 'responsive navigation must reuse the authenticated read');
  });
}

class _SmokeRelationalRepository implements RelationalCoachingRepository {
  int fetchCount = 0;

  @override
  Future<RelationalCoachingData> fetch() async {
    fetchCount++;
    final now = DateTime.now();
    return RelationalCoachingData(
      athlete: {
        'current_ftp': 246,
        'body_mass_kg': 72,
        'maximum_hr': 190,
        'updated_at': now.toUtc().toIso8601String(),
      },
      activities: [
        {
          'id': 'smoke-ride',
          'started_at': now.subtract(const Duration(days: 1)).toIso8601String(),
          'duration_seconds': 3600,
          'distance_metres': 32000,
          'elevation_metres': 250,
          'average_power': 190,
          'training_load': 65,
          'updated_at': now.toUtc().toIso8601String(),
          'source_payload': {'name': 'Synthetic endurance ride'},
        },
      ],
      wellness: [
        {
          'recorded_date': now.toIso8601String().substring(0, 10),
          'sleep_minutes': 450,
          'hrv_ms': 54,
          'resting_hr': 50,
          'resolved_at': now.toUtc().toIso8601String(),
        },
      ],
      weights: const [],
      plannedSessions: [
        {
          'scheduled_date': now
              .add(const Duration(days: 1))
              .toIso8601String()
              .substring(0, 10),
          'session_type': 'endurance',
          'purpose': 'Synthetic planned endurance',
          'planned_duration_minutes': 75,
          'planned_load': 50,
          'adaptation_status': 'KEEP',
        },
      ],
      ftpHistory: const [],
      nutritionEntries: const [],
      nutritionTargets: const [],
      latestReadiness: const {'readiness_score': 78},
      latestDecision: null,
      updatedAt: now.toUtc(),
    );
  }
}
