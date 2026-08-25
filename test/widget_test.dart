import 'package:cycle_ready/src/app.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/health/application/health_connection_controller.dart';
import 'package:cycle_ready/src/features/sync/application/sync_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard displays readiness and training summary',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recoveryControllerProvider.overrideWith(_FakeRecoveryController.new),
          todayCheckInCompletedProvider.overrideWith((ref) async => true),
          healthConnectionControllerProvider
              .overrideWith(_FakeHealthConnectionController.new),
          appSyncControllerProvider.overrideWith(_FakeSyncController.new),
        ],
        child: const CycleReadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('READINESS'), findsOneWidget);
    expect(find.text('Train with care'), findsOneWidget);
    expect(find.text('SYNC STATUS SENTINEL'), findsNothing);

    expect(find.text('SLEEP'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('WHY TODAY'), findsOneWidget);
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    expect(find.text('Training Plan'), findsOneWidget);
    expect(find.text('RIDES'), findsOneWidget);

    await tester.tap(find.text('Rides').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar).last)
          .selectedIndex,
      1,
    );

    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();

    expect(find.text('Training Plan'), findsOneWidget);
    expect(find.text('Add workout'), findsOneWidget);
  });
}

class _FakeRecoveryController extends RecoveryController {
  @override
  Future<RecoveryInput> build() async => RecoveryInput.defaults();
}

class _FakeHealthConnectionController extends HealthConnectionController {
  @override
  Future<HealthConnectionState> build() async =>
      const HealthConnectionState(authorized: false);
}

class _FakeSyncController extends AppSyncController {
  @override
  Future<AppSyncState> build() async =>
      const AppSyncState(message: 'SYNC STATUS SENTINEL');
}
