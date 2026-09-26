import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _phase = String.fromEnvironment('CYCLEREADY_UPGRADE_SMOKE_PHASE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('upgrade installation preserves local athlete data', (_) async {
    expect(
      const {'seed', 'verify'},
      contains(_phase),
      reason: 'Set CYCLEREADY_UPGRADE_SMOKE_PHASE to seed or verify.',
    );
    final database = AppDatabase();
    addTearDown(database.close);

    if (_phase == 'seed') {
      await database.eraseAllUserData();
      await database.saveAthleteSettings(
        AthleteSettingsCompanion.insert(
          athleteName: const Value('Upgrade smoke athlete'),
          ftp: const Value(246),
          weightKg: const Value(71.8),
          trainingLocation: const Value('Synthetic location'),
        ),
      );
      await database.saveActivity(
        ActivitiesCompanion.insert(
          id: 'upgrade-smoke-ride',
          title: const Value('Synthetic endurance ride'),
          source: 'upgradeSmoke',
          startedAt: DateTime.utc(2026, 9, 20, 8),
          durationSeconds: 5400,
          distanceMetres: 42000,
          averagePower: const Value(188),
          trainingLoad: const Value(72),
        ),
        const [],
      );
      await database.saveRecovery(
        DailyRecoveryRecordsCompanion.insert(
          day: DateTime.utc(2026, 9, 21),
          sleepMinutes: const Value(465),
          hrvMilliseconds: const Value(54),
        ),
      );
      await database.savePlannedSession(
        PlannedSessionsCompanion.insert(
          day: DateTime.utc(2026, 9, 22),
          sessionType: 'endurance',
          title: 'Upgrade smoke workout',
          durationMinutes: 60,
          targetLoad: 42,
        ),
      );
      expect((await database.getActivities()).single.id, 'upgrade-smoke-ride');
      return;
    }

    final athlete = await database.getAthleteSettings();
    final rides = await database.getActivities();
    final recovery = await database.recoveryForDay(DateTime.utc(2026, 9, 21));
    final sessions = await database.getPlannedSessions(
      DateTime.utc(2026, 9, 22),
      DateTime.utc(2026, 9, 22),
    );

    expect(athlete.athleteName, 'Upgrade smoke athlete');
    expect(athlete.ftp, 246);
    expect(athlete.weightKg, 71.8);
    expect(rides.single.id, 'upgrade-smoke-ride');
    expect(rides.single.trainingLoad, 72);
    expect(recovery?.sleepMinutes, 465);
    expect(recovery?.hrvMilliseconds, 54);
    expect(sessions.single.title, 'Upgrade smoke workout');
  });
}
