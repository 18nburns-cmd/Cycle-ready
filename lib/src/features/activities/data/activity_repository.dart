import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';

final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(ref.watch(databaseProvider)),
);

final activitiesProvider = StreamProvider<List<Activity>>(
  (ref) => ref.watch(activityRepositoryProvider).watchAll(),
);

final athleteSettingsProvider = StreamProvider<AthleteSetting?>(
  (ref) => ref.watch(databaseProvider).watchAthleteSettings(),
);

final fitnessMetricsProvider = Provider<TrainingMetrics>((ref) {
  final rides = ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
  final settings = ref.watch(athleteSettingsProvider).valueOrNull;
  final strength = ref.watch(strengthWorkloadsProvider).valueOrNull ?? const [];
  return calculateFitnessMetrics(
    [
      ...rides.map((ride) {
        final estimated = estimateActivityLoad(
          durationSeconds: ride.durationSeconds,
          normalisedPower: ride.normalisedPower,
          averageHeartRate: ride.averageHeartRate,
          ftp: settings?.ftp ?? 200,
          restingHeartRate: settings?.restingHeartRate ?? 50,
          maximumHeartRate: settings?.maximumHeartRate ?? 190,
        );
        return (
          date: ride.startedAt,
          load: ride.trainingLoad?.toDouble() ?? estimated.value,
        );
      }),
      ...strength.map((workout) => (
            date: workout.completedAt,
            load: workout.load,
          )),
    ],
    DateTime.now(),
  );
});

class ActivityRepository {
  const ActivityRepository(this.database);
  final AppDatabase database;

  Stream<List<Activity>> watchAll() => database.watchActivities();
  Future<Activity?> byId(String id) => database.activityById(id);
  Future<List<ActivitySample>> samplesFor(String id) => database.samplesFor(id);
}
