import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/coaching/data/supabase_workout_delivery_status_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WorkoutDeliveryDateRange = ({DateTime start, DateTime end});

final workoutDeliveryStatusRepositoryProvider =
    Provider<WorkoutDeliveryStatusRepository?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured) return null;
  return SupabaseWorkoutDeliveryStatusRepository(Supabase.instance.client);
});

final workoutDeliveryStatusesProvider = FutureProvider.family<
    List<CalendarWorkoutDeliveryState>, WorkoutDeliveryDateRange>(
  (ref, range) async =>
      await ref.watch(workoutDeliveryStatusRepositoryProvider)?.fetchRange(
            range.start,
            range.end,
          ) ??
      const [],
);

class WorkoutDeliveryRetryController {
  const WorkoutDeliveryRetryController(this.ref);
  final Ref ref;

  Future<bool> retry(
      String plannedSessionId, WorkoutDeliveryDateRange range) async {
    final repository = ref.read(workoutDeliveryStatusRepositoryProvider);
    if (repository == null) return false;
    final retried = await repository.retry(
      plannedSessionId,
      provider: 'intervals-icu',
    );
    ref.invalidate(workoutDeliveryStatusesProvider(range));
    return retried;
  }

  Future<int> retryFuture(WorkoutDeliveryDateRange range) async {
    final repository = ref.read(workoutDeliveryStatusRepositoryProvider);
    if (repository == null) return 0;
    final count = await repository.retryFuture(provider: 'intervals-icu');
    ref.invalidate(workoutDeliveryStatusesProvider(range));
    return count;
  }
}

final workoutDeliveryRetryControllerProvider =
    Provider(WorkoutDeliveryRetryController.new);
