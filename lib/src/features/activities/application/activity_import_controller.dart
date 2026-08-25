import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/fit_import_service.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/coaching/application/coach_reminder_controller.dart';
import 'package:cycle_ready/src/features/nutrition/domain/recovery_nutrition.dart';

final activityImportControllerProvider =
    AsyncNotifierProvider<ActivityImportController, String?>(
  ActivityImportController.new,
);

final intervalsAutoSyncProvider = FutureProvider<int>((ref) async {
  final credentials = await ref.read(intervalsIcuServiceProvider).credentials();
  if (credentials == null) return 0;
  return ref.read(activityImportControllerProvider.notifier).syncIntervals();
});

final activityDetailSamplesProvider =
    FutureProvider.family<List<ActivitySample>, String>((ref, id) async {
  final database = ref.read(databaseProvider);
  final existing = await database.samplesFor(id);
  if (existing.isNotEmpty) return existing;
  final activity = await database.activityById(id);
  if (activity?.source != 'intervalsIcu' || activity?.externalId == null) {
    return existing;
  }
  final remote = await ref
      .read(intervalsIcuServiceProvider)
      .fetchActivitySamples(activity!.externalId!);
  if (remote.isNotEmpty) {
    await database.saveActivitySamples(
      remote
          .map((sample) => ActivitySamplesCompanion.insert(
                activityId: id,
                elapsedSeconds: sample.elapsedSeconds,
                heartRate: Value(sample.heartRate),
                power: Value(sample.watts),
                cadence: Value(sample.cadence),
                altitudeMetres: Value(sample.altitudeMetres),
                distanceMetres: Value(sample.distanceMetres),
                latitude: Value(sample.latitude),
                longitude: Value(sample.longitude),
              ))
          .toList(),
    );
  }
  return database.samplesFor(id);
});

class ActivityImportController extends AsyncNotifier<String?> {
  AppDatabase get _database => ref.read(databaseProvider);

  @override
  Future<String?> build() async => null;

  Future<void> importFitFile() async {
    const group = XTypeGroup(label: 'FIT activity', extensions: ['fit']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final parsed = FitImportService().parse(await file.readAsBytes());
      final duplicate = await _database.hasActivityMatch(
        fileHash: parsed.hash,
        startedAt: parsed.startedAt,
        durationSeconds: parsed.durationSeconds,
      );
      if (duplicate) return 'That ride is already in CycleReady.';
      final settings = await _database.getAthleteSettings();
      final load = parsed.normalisedPower == null
          ? null
          : calculateTrainingLoad(
              durationSeconds: parsed.durationSeconds,
              normalisedPower: parsed.normalisedPower!,
              ftp: settings.ftp,
            ).round();
      final id = 'fit-${parsed.hash.substring(0, 16)}';
      await _database.saveActivity(
        ActivitiesCompanion.insert(
          id: id,
          title: const Value('Imported ride'),
          source: 'fitFile',
          fileHash: Value(parsed.hash),
          startedAt: parsed.startedAt,
          durationSeconds: parsed.durationSeconds,
          distanceMetres: parsed.distanceMetres,
          elevationMetres: Value(parsed.elevationMetres),
          averageHeartRate: Value(parsed.averageHeartRate),
          maximumHeartRate: Value(parsed.maximumHeartRate),
          averagePower: Value(parsed.averagePower),
          maximumPower: Value(parsed.maximumPower),
          normalisedPower: Value(parsed.normalisedPower),
          averageCadence: Value(parsed.averageCadence),
          trainingLoad: Value(load),
        ),
        parsed.samples
            .map((sample) => ActivitySamplesCompanion.insert(
                  activityId: id,
                  elapsedSeconds: sample.elapsedSeconds,
                  heartRate: Value(sample.heartRate),
                  power: Value(sample.power),
                  cadence: Value(sample.cadence),
                  altitudeMetres: Value(sample.altitudeMetres),
                  distanceMetres: Value(sample.distanceMetres),
                ))
            .toList(),
      );
      await _notifyRecoveryIfRecent(
        activityId: id,
        title: 'Imported ride',
        startedAt: parsed.startedAt,
        durationSeconds: parsed.durationSeconds,
        trainingLoad: load ?? 0,
      );
      return 'FIT ride imported successfully.';
    });
  }

  Future<int> importHealthWorkouts(List<ImportedWorkout> workouts) async {
    var imported = 0;
    for (final workout in workouts) {
      if (await _database.hasActivityMatch(
        externalId: workout.externalId,
        startedAt: workout.startedAt,
        durationSeconds: workout.durationSeconds,
      )) {
        continue;
      }
      await _database.saveActivity(
        ActivitiesCompanion.insert(
          id: 'hc-${workout.externalId}',
          title: const Value('Cycling workout'),
          source: 'healthConnect',
          externalId: Value(workout.externalId),
          startedAt: workout.startedAt,
          durationSeconds: workout.durationSeconds,
          distanceMetres: workout.distanceMetres,
          calories: Value(workout.calories),
        ),
        const [],
      );
      await _notifyRecoveryIfRecent(
        activityId: 'hc-${workout.externalId}',
        title: 'Cycling workout',
        startedAt: workout.startedAt,
        durationSeconds: workout.durationSeconds,
        trainingLoad: 0,
      );
      imported++;
    }
    return imported;
  }

  Future<int> syncIntervals() async {
    final remote =
        await ref.read(intervalsIcuServiceProvider).fetchRecentActivities();
    var imported = 0;
    var detailed = 0;
    for (final ride in remote) {
      final existing = await _database.findActivityMatch(
        externalId: ride.id,
        startedAt: ride.startedAt,
        durationSeconds: ride.durationSeconds,
      );
      final id = existing?.id ?? 'intervals-${ride.id}';
      await _database.saveActivity(
        ActivitiesCompanion.insert(
          id: id,
          title: Value(ride.name),
          source: 'intervalsIcu',
          externalId: Value(ride.id),
          startedAt: ride.startedAt,
          durationSeconds: ride.durationSeconds,
          distanceMetres: ride.distanceMetres,
          elevationMetres: Value(ride.elevationMetres),
          averageHeartRate: Value(ride.averageHeartRate),
          maximumHeartRate: Value(ride.maximumHeartRate),
          averagePower: Value(ride.averagePower),
          normalisedPower: Value(ride.normalisedPower),
          averageCadence: Value(ride.averageCadence),
          trainingLoad: Value(ride.trainingLoad),
          calories: Value(ride.calories),
        ),
        const [],
      );
      if (existing == null) {
        await _notifyRecoveryIfRecent(
          activityId: id,
          title: ride.name,
          startedAt: ride.startedAt,
          durationSeconds: ride.durationSeconds,
          trainingLoad: ride.trainingLoad ?? 0,
        );
      }
      final savedSamples = await _database.samplesFor(id);
      if (detailed < 10 && savedSamples.isEmpty) {
        try {
          final samples = await ref
              .read(intervalsIcuServiceProvider)
              .fetchActivitySamples(ride.id);
          await _database.saveActivitySamples(
            samples
                .map((sample) => ActivitySamplesCompanion.insert(
                      activityId: id,
                      elapsedSeconds: sample.elapsedSeconds,
                      heartRate: Value(sample.heartRate),
                      power: Value(sample.watts),
                      cadence: Value(sample.cadence),
                      altitudeMetres: Value(sample.altitudeMetres),
                      distanceMetres: Value(sample.distanceMetres),
                      latitude: Value(sample.latitude),
                      longitude: Value(sample.longitude),
                    ))
                .toList(),
          );
          detailed++;
        } catch (_) {
          // A summary is still useful when a historic activity has no streams.
        }
      }
      if (existing == null) imported++;
    }
    return imported;
  }

  Future<void> syncIntervalsNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final count = await syncIntervals();
      ref.invalidate(activitiesProvider);
      final restricted =
          ref.read(intervalsIcuServiceProvider).lastRestrictedActivityCount;
      if (restricted > 0) {
        return 'Imported $count new ride${count == 1 ? '' : 's'}. '
            '$restricted Strava-sourced activit${restricted == 1 ? 'y was' : 'ies were'} '
            'not available through the Intervals.icu API. Connect Garmin '
            'directly to Intervals or import the FIT file.';
      }
      return count == 0
          ? 'Intervals.icu rides are up to date.'
          : 'Imported $count ride${count == 1 ? '' : 's'} with detailed data.';
    });
  }

  Future<void> _notifyRecoveryIfRecent({
    required String activityId,
    required String title,
    required DateTime startedAt,
    required int durationSeconds,
    required int trainingLoad,
  }) async {
    final finishedAt = startedAt.add(Duration(seconds: durationSeconds));
    final age = DateTime.now().difference(finishedAt);
    if (age.isNegative || age > const Duration(hours: 12)) return;
    final settings = await _database.getAthleteSettings();
    final recommendation = calculateRecoveryNutrition(
      weightKg: settings.weightKg,
      durationSeconds: durationSeconds,
      trainingLoad: trainingLoad,
    );
    await ref.read(coachReminderServiceProvider).showRecovery(
          activityId: activityId,
          rideTitle: title,
          body: recommendation.notificationBody,
        );
  }
}
