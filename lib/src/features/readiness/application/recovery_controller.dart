import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/intervals/domain/intervals_wellness.dart';

final recoveryControllerProvider =
    AsyncNotifierProvider<RecoveryController, RecoveryInput>(
        RecoveryController.new);

final todayCheckInCompletedProvider = FutureProvider<bool>((ref) async {
  final record =
      await ref.watch(databaseProvider).recoveryForDay(DateTime.now());
  return record?.fatigue != null &&
      record?.soreness != null &&
      record?.stress != null &&
      record?.motivation != null;
});

final latestSleepEndProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(databaseProvider).watchLatestSleepEnd(),
);

class RecoveryController extends AsyncNotifier<RecoveryInput> {
  AppDatabase get _database => ref.read(databaseProvider);

  @override
  Future<RecoveryInput> build() async {
    final record = await _database.recoveryForDay(DateTime.now());
    return record == null ? RecoveryInput.defaults() : _fromRecord(record);
  }

  Future<bool> saveCheckIn({
    required int fatigue,
    required int soreness,
    required int stress,
    required int motivation,
  }) async {
    final existing = await _database.recoveryForDay(DateTime.now());
    final alreadyCompleted = existing?.fatigue != null &&
        existing?.soreness != null &&
        existing?.stress != null &&
        existing?.motivation != null;
    if (alreadyCompleted) return false;
    final current = state.valueOrNull ?? RecoveryInput.defaults();
    final updated = current.copyWith(
      fatigue: fatigue,
      soreness: soreness,
      stress: stress,
      motivation: motivation,
      hasCheckIn: true,
    );
    state = AsyncData(updated);
    final now = DateTime.now();
    await _database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: DateTime(now.year, now.month, now.day),
      fatigue: Value(fatigue),
      soreness: Value(soreness),
      stress: Value(stress),
      motivation: Value(motivation),
    ));
    ref.invalidate(todayCheckInCompletedProvider);
    return true;
  }

  Future<void> applyHealthSnapshot(HealthSnapshot snapshot) async {
    final current = state.valueOrNull ?? RecoveryInput.defaults();
    final useIntervals =
        await ref.read(intervalsIcuServiceProvider).credentials() != null;
    final updated = current.copyWith(
      sleepMinutes: snapshot.sleepMinutes ?? current.sleepMinutes,
      restingHeartRate: useIntervals
          ? current.restingHeartRate
          : snapshot.restingHeartRate ?? current.restingHeartRate,
      hrvMilliseconds: snapshot.hrvMilliseconds ?? current.hrvMilliseconds,
      hasHealthData: snapshot.sleepMinutes != null ||
          snapshot.restingHeartRate != null ||
          snapshot.hrvMilliseconds != null,
      hasSleepData: snapshot.sleepMinutes != null || current.hasSleepData,
      hasRecoverySignals: snapshot.restingHeartRate != null ||
          snapshot.hrvMilliseconds != null ||
          current.hasRecoverySignals,
    );
    state = AsyncData(updated);
    final now = DateTime.now();
    await _database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: DateTime(now.year, now.month, now.day),
      sleepMinutes: snapshot.sleepMinutes == null
          ? const Value.absent()
          : Value(snapshot.sleepMinutes),
      sleepEndedAt: snapshot.sleepEndedAt == null
          ? const Value.absent()
          : Value(snapshot.sleepEndedAt),
      restingHeartRate: useIntervals || snapshot.restingHeartRate == null
          ? const Value.absent()
          : Value(snapshot.restingHeartRate),
      hrvMilliseconds: snapshot.hrvMilliseconds == null
          ? const Value.absent()
          : Value(snapshot.hrvMilliseconds),
    ));
  }

  Future<void> applyIntervalsHeartRate(IntervalsHeartRateSummary summary,
      {IntervalsHrvSummary? hrv}) async {
    final current = state.valueOrNull ?? RecoveryInput.defaults();
    final updated = current.copyWith(
      restingHeartRate: summary.latest,
      baselineRestingHeartRate: summary.baseline,
      hrvMilliseconds: hrv?.latest ?? current.hrvMilliseconds,
      baselineHrvMilliseconds: hrv?.baseline,
      hasHealthData: true,
      hasRecoverySignals: true,
    );
    state = AsyncData(updated);
    final now = DateTime.now();
    await _database.saveRecovery(DailyRecoveryRecordsCompanion.insert(
      day: DateTime(now.year, now.month, now.day),
      restingHeartRate: Value(summary.latest),
      hrvMilliseconds: hrv == null ? const Value.absent() : Value(hrv.latest),
    ));
  }

  RecoveryInput _fromRecord(DailyRecoveryRecord record) => RecoveryInput(
        sleepMinutes: record.sleepMinutes ?? 0,
        sleepTargetMinutes: 480,
        sleepQuality: record.sleepQuality ?? 70,
        restingHeartRate: record.restingHeartRate ?? 50,
        baselineRestingHeartRate: 50,
        hrvMilliseconds: record.hrvMilliseconds,
        baselineHrvMilliseconds: 58,
        recentTrainingLoad: record.acuteTrainingLoad ?? 0,
        normalTrainingLoad: 320,
        fatigue: record.fatigue ?? 3,
        soreness: record.soreness ?? 3,
        stress: record.stress ?? 3,
        motivation: record.motivation ?? 3,
        hasHealthData: record.sleepMinutes != null ||
            record.restingHeartRate != null ||
            record.hrvMilliseconds != null,
        hasSleepData: record.sleepMinutes != null,
        hasRecoverySignals:
            record.restingHeartRate != null || record.hrvMilliseconds != null,
        hasCheckIn: record.fatigue != null &&
            record.soreness != null &&
            record.stress != null &&
            record.motivation != null,
      );
}
