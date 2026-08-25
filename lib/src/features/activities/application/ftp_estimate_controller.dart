import 'package:cycle_ready/src/core/database/app_database.dart' as db;
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/ftp_estimator.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ftpEstimateHistoryProvider = StreamProvider<List<db.FtpEstimate>>(
  (ref) => ref.watch(databaseProvider).watchFtpEstimates(),
);

final ftpEstimateControllerProvider =
    AsyncNotifierProvider<FtpEstimateController, FtpEstimate?>(
  FtpEstimateController.new,
);

class FtpEstimateController extends AsyncNotifier<FtpEstimate?> {
  @override
  Future<FtpEstimate?> build() async => null;

  Future<void> calculate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final oldest = now.subtract(const Duration(days: 56));
      final rides = ref
              .read(activitiesProvider)
              .valueOrNull
              ?.where((ride) => !ride.startedAt.isBefore(oldest))
              .toList() ??
          const <db.Activity>[];
      final powerRides = <PowerRide>[];
      for (final ride in rides) {
        var samples = await ref.read(databaseProvider).samplesFor(ride.id);
        if (!samples.any((sample) => sample.power != null) &&
            ride.source == 'intervalsIcu' &&
            ride.externalId != null) {
          final remote = await ref
              .read(intervalsIcuServiceProvider)
              .fetchPowerSamples(ride.externalId!);
          if (remote.isNotEmpty) {
            await ref.read(databaseProvider).saveActivitySamples(
                  remote
                      .map((sample) => db.ActivitySamplesCompanion.insert(
                            activityId: ride.id,
                            elapsedSeconds: sample.elapsedSeconds,
                            power: Value(sample.watts),
                          ))
                      .toList(),
                );
            samples = await ref.read(databaseProvider).samplesFor(ride.id);
          }
        }
        final powerSamples = samples
            .where((sample) => sample.power != null)
            .map((sample) => PowerSample(
                  sample.elapsedSeconds,
                  sample.power!,
                ))
            .toList();
        if (powerSamples.isEmpty) continue;
        powerRides.add(PowerRide(
          date: ride.startedAt,
          durationSeconds: ride.durationSeconds,
          samples: powerSamples,
        ));
      }
      final estimate = estimateFtp(powerRides, now: now);
      if (estimate != null) {
        await ref.read(databaseProvider).saveFtpEstimate(
              db.FtpEstimatesCompanion.insert(
                estimatedAt: now,
                windowStart: oldest,
                watts: estimate.watts,
                lowWatts: estimate.lowWatts,
                highWatts: estimate.highWatts,
                confidence: estimate.confidence.name,
                rideCount: estimate.rideCount,
                durationCoverage: estimate.durationCoverage,
                accepted: const Value(false),
              ),
            );
      }
      return estimate;
    });
  }

  Future<void> acceptLatest() async {
    final history =
        ref.read(ftpEstimateHistoryProvider).valueOrNull ?? const [];
    if (history.isEmpty) return;
    await ref.read(databaseProvider).acceptFtpEstimate(history.first);
  }
}
