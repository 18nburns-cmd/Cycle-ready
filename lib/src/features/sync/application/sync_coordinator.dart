import 'dart:async';

import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/health/application/health_connection_controller.dart';
import 'package:cycle_ready/src/features/intervals/application/intervals_wellness_controller.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/coaching/application/morning_plan_adapter.dart';
import 'package:cycle_ready/src/features/coaching/application/plan_completion_adapter.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const automaticSyncInterval = Duration(minutes: 10);

Duration syncRetryDelay(int consecutiveFailures) =>
    switch (consecutiveFailures.clamp(1, 5)) {
      1 => const Duration(minutes: 2),
      2 => const Duration(minutes: 5),
      3 => const Duration(minutes: 15),
      4 => const Duration(minutes: 30),
      _ => const Duration(hours: 1),
    };

bool automaticSyncIsDue(
  DateTime? lastAttempt,
  DateTime now, {
  DateTime? nextRetryAt,
}) {
  if (nextRetryAt != null && now.isBefore(nextRetryAt)) return false;
  return lastAttempt == null ||
      now.difference(lastAttempt) >= automaticSyncInterval;
}

class AppSyncState {
  const AppSyncState({
    this.syncing = false,
    this.lastAttempt,
    this.lastSuccess,
    this.importedRides = 0,
    this.consecutiveFailures = 0,
    this.nextRetryAt,
    this.message = 'Waiting for automatic sync.',
  });

  final bool syncing;
  final DateTime? lastAttempt;
  final DateTime? lastSuccess;
  final int importedRides;
  final int consecutiveFailures;
  final DateTime? nextRetryAt;
  final String message;

  AppSyncState copyWith({
    bool? syncing,
    DateTime? lastAttempt,
    DateTime? lastSuccess,
    int? importedRides,
    int? consecutiveFailures,
    DateTime? nextRetryAt,
    String? message,
  }) =>
      AppSyncState(
        syncing: syncing ?? this.syncing,
        lastAttempt: lastAttempt ?? this.lastAttempt,
        lastSuccess: lastSuccess ?? this.lastSuccess,
        importedRides: importedRides ?? this.importedRides,
        consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        message: message ?? this.message,
      );
}

final appSyncControllerProvider =
    AsyncNotifierProvider<AppSyncController, AppSyncState>(
  AppSyncController.new,
);

class AppSyncController extends AsyncNotifier<AppSyncState> {
  static const _lastSuccessKey = 'cycle_ready_last_successful_sync';
  static const _failureCountKey = 'cycle_ready_sync_failure_count';
  static const _nextRetryKey = 'cycle_ready_next_sync_retry';
  final _storage = const FlutterSecureStorage();
  Timer? _retryTimer;

  @override
  Future<AppSyncState> build() async {
    final stored = await _storage.read(key: _lastSuccessKey);
    final storedFailures = await _storage.read(key: _failureCountKey);
    final storedRetry = await _storage.read(key: _nextRetryKey);
    final initial = AppSyncState(
      lastSuccess: stored == null ? null : DateTime.tryParse(stored),
      consecutiveFailures: int.tryParse(storedFailures ?? '') ?? 0,
      nextRetryAt: storedRetry == null ? null : DateTime.tryParse(storedRetry),
    );
    ref.onDispose(() => _retryTimer?.cancel());
    _scheduleRetry(initial.nextRetryAt);
    return initial;
  }

  Future<void> sync({bool force = false}) async {
    final current = state.valueOrNull ?? const AppSyncState();
    final now = DateTime.now();
    if (current.syncing ||
        (!force &&
            !automaticSyncIsDue(
              current.lastAttempt,
              now,
              nextRetryAt: current.nextRetryAt,
            ))) {
      return;
    }
    state = AsyncData(current.copyWith(
      syncing: true,
      lastAttempt: now,
      message: 'Refreshing connected services…',
    ));

    final successes = <String>[];
    final failures = <String>[];
    var imported = 0;

    try {
      await ref.read(healthConnectionControllerProvider.future);
      final initialHealth =
          ref.read(healthConnectionControllerProvider).valueOrNull;
      if (initialHealth?.authorized == true) {
        await ref
            .read(healthConnectionControllerProvider.notifier)
            .syncIfAuthorized();
        final health = ref.read(healthConnectionControllerProvider).valueOrNull;
        if (health?.authorized == true) successes.add('health');
      }
    } catch (_) {
      failures.add('health');
    }

    try {
      final intervals = ref.read(intervalsIcuServiceProvider);
      if (await intervals.credentials() != null) {
        imported = await ref
            .read(activityImportControllerProvider.notifier)
            .syncIntervals();
        ref.invalidate(powerRideInputsProvider);
        ref.invalidate(intervalsWellnessAutoSyncProvider);
        await ref.read(intervalsWellnessAutoSyncProvider.future);
        successes.add('Intervals.icu');
      }
    } catch (_) {
      failures.add('Intervals.icu');
    }

    try {
      final completionChanged =
          await ref.read(planCompletionAdapterProvider).adaptFromYesterday();
      final changed = await ref.read(morningPlanAdapterProvider).adaptToday();
      final extended = await ref
          .read(plannedSessionControllerProvider)
          .maintainRollingPlan();
      if (changed || completionChanged || extended) {
        successes.add('training plan');
      }
    } catch (_) {
      failures.add('training plan');
    }

    final finished = DateTime.now();
    if (successes.isNotEmpty) {
      await _storage.write(
        key: _lastSuccessKey,
        value: finished.toIso8601String(),
      );
    }
    final shouldRetry = failures.isNotEmpty;
    final failureCount = shouldRetry ? current.consecutiveFailures + 1 : 0;
    final nextRetry =
        shouldRetry ? finished.add(syncRetryDelay(failureCount)) : null;
    if (shouldRetry) {
      await _storage.write(
        key: _failureCountKey,
        value: '$failureCount',
      );
      await _storage.write(
        key: _nextRetryKey,
        value: nextRetry!.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _failureCountKey);
      await _storage.delete(key: _nextRetryKey);
    }
    final message = successes.isEmpty && failures.isEmpty
        ? 'No connected data sources are available.'
        : failures.isEmpty
            ? 'Synced ${successes.join(' and ')}'
                '${imported > 0 ? ' · $imported new rides' : ''}.'
            : successes.isEmpty
                ? 'Sync could not reach ${failures.join(' and ')}. Retry scheduled in ${_retryMinutes(failureCount)} minutes.'
                : 'Synced ${successes.join(' and ')}; '
                    '${failures.join(' and ')} will retry in ${_retryMinutes(failureCount)} minutes.';
    state = AsyncData(AppSyncState(
      syncing: false,
      lastAttempt: now,
      lastSuccess: successes.isEmpty ? current.lastSuccess : finished,
      importedRides: imported,
      consecutiveFailures: failureCount,
      nextRetryAt: nextRetry,
      message: message,
    ));
    _scheduleRetry(nextRetry);
  }

  int _retryMinutes(int failureCount) => syncRetryDelay(failureCount).inMinutes;

  void _scheduleRetry(DateTime? at) {
    _retryTimer?.cancel();
    if (at == null) return;
    final delay = at.difference(DateTime.now());
    _retryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => sync(force: true),
    );
  }
}
