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

final todayDailyCoachingRecommendationProvider =
    FutureProvider<DailyCoachingRecommendation?>((ref) async {
  final repository = ref.watch(dailyCoachingStatusRepositoryProvider);
  if (repository == null) {
    developer.log(
      'Offline fallback activated: Supabase is not configured in this build.',
      name: 'CycleReady.serverCoaching',
    );
    return null;
  }
  final recommendation = await repository.fetchToday();
  if (recommendation == null) {
    developer.log(
      'Offline fallback activated: no authenticated recommendation returned.',
      name: 'CycleReady.serverCoaching',
    );
  }
  return recommendation;
});
