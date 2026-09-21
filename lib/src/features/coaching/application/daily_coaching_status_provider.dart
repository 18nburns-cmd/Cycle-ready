import 'dart:async';
import 'dart:developer' as developer;

import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/coaching/data/supabase_daily_coaching_status_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dailyCoachingStatusRepositoryProvider =
    Provider<DailyCoachingStatusRepository?>(
  (ref) => ref.watch(cloudConfigProvider).isConfigured
      ? SupabaseDailyCoachingStatusRepository(Supabase.instance.client)
      : null,
);

final dailyCoachingStatusProvider = FutureProvider<DailyCoachingStatus>(
  (ref) {
    final repository = ref.watch(dailyCoachingStatusRepositoryProvider);
    if (repository == null) {
      throw StateError('Server coaching is not configured.');
    }
    return repository.fetchStatus();
  },
);

final serverCoachingRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

final todayDailyCoachingRecommendationProvider =
    FutureProvider.autoDispose<DailyCoachingRecommendation?>((ref) async {
  final accountState = ref.watch(cloudAccountProvider);
  final account = accountState.isLoading
      ? await ref.watch(cloudAccountProvider.future)
      : accountState.valueOrNull;
  if (account == null) {
    developer.log(
      'Offline fallback activated: no authenticated cloud account is ready.',
      name: 'CycleReady.serverCoaching',
    );
    return null;
  }
  final repository = ref.watch(dailyCoachingStatusRepositoryProvider);
  if (repository == null) {
    developer.log(
      'Offline fallback activated: Supabase is not configured in this build.',
      name: 'CycleReady.serverCoaching',
    );
    return null;
  }
  try {
    final recommendation = await repository.fetchToday();
    if (recommendation == null) {
      _scheduleServerCoachingRetry(ref);
      developer.log(
        'Offline fallback activated: no authenticated recommendation returned.',
        name: 'CycleReady.serverCoaching',
      );
    }
    return recommendation;
  } catch (error, stackTrace) {
    _scheduleServerCoachingRetry(ref);
    developer.log(
      'Offline fallback activated: authoritative recommendation request failed; '
      'a retry has been scheduled.',
      name: 'CycleReady.serverCoaching',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
});

void _scheduleServerCoachingRetry(Ref ref) {
  final timer = Timer(
    ref.read(serverCoachingRetryDelayProvider),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
}
