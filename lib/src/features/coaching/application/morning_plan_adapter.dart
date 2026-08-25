import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/morning_plan_adaptation.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final morningPlanAdapterProvider = Provider(MorningPlanAdapter.new);

class MorningPlanAdapter {
  const MorningPlanAdapter(this.ref);
  final Ref ref;

  Future<bool> adaptToday() async {
    ref.invalidate(activitiesProvider);
    ref.invalidate(strengthWorkloadsProvider);
    await ref.read(activitiesProvider.future);
    await ref.read(strengthWorkloadsProvider.future);
    final database = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessions = await database.getPlannedSessions(today, today);
    if (sessions.isEmpty) return false;
    final existing = sessions.single;
    if (existing.origin != 'adaptive') return false;
    final type = SessionType.values.firstWhere(
      (value) => value.name == existing.sessionType,
      orElse: () => SessionType.endurance,
    );
    final metrics = ref.read(fitnessMetricsProvider);
    final change = adaptMorningWorkout(
      existingType: type,
      readiness: ref.read(todayReadinessProvider).score,
      form: metrics.form,
      rampRate: metrics.rampRate,
    );
    if (change == null) return false;
    final athlete = await database.getAthleteSettings();
    final prescription = change.type == SessionType.recovery
        ? 'Below ${(athlete.ftp * .55).round()} W · keep this genuinely easy'
        : '${(athlete.ftp * .58).round()}–${(athlete.ftp * .68).round()} W · controlled aerobic work';
    await database.savePlannedSession(
      PlannedSessionsCompanion.insert(
        day: today,
        sessionType: change.type.name,
        title: change.title,
        durationMinutes: change.durationMinutes,
        targetLoad: change.targetLoad,
        confirmed: Value(existing.confirmed),
        prescription: Value(prescription),
        origin: const Value('adaptive'),
        adaptationReason: Value(change.reason),
      ),
    );
    return true;
  }
}
