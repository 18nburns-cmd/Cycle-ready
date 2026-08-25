import 'package:cycle_ready/src/features/health/data/health_connect_repository.dart';
import 'package:cycle_ready/src/features/health/domain/health_snapshot.dart';
import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/body/data/drift_body_measurement_repository.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

final healthRepositoryProvider = Provider((ref) => HealthConnectRepository());

final healthConnectionControllerProvider =
    AsyncNotifierProvider<HealthConnectionController, HealthConnectionState>(
        HealthConnectionController.new);

class HealthConnectionState {
  const HealthConnectionState({
    required this.authorized,
    this.lastSnapshot,
    this.message,
  });

  final bool authorized;
  final HealthSnapshot? lastSnapshot;
  final String? message;
}

class HealthConnectionController extends AsyncNotifier<HealthConnectionState> {
  HealthConnectRepository get _repository => ref.read(healthRepositoryProvider);

  @override
  Future<HealthConnectionState> build() async {
    try {
      final granted = await _repository.grantedTypes();
      if (granted.isEmpty) {
        return const HealthConnectionState(authorized: false);
      }
      return _sync(
        granted,
        message: 'Health Connect synced automatically when CycleReady opened.',
      );
    } catch (_) {
      return const HealthConnectionState(
        authorized: false,
        message: 'Health Connect is unavailable or still needs permission.',
      );
    }
  }

  Future<void> connectAndSync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authorized = await _repository.requestPermissions();
      final granted = await _repository.grantedTypes();
      if (!authorized && granted.isEmpty) {
        return const HealthConnectionState(
          authorized: false,
          message:
              'No data was read. You can change access in Health Connect settings.',
        );
      }
      return _sync(
        granted,
        message: 'Your latest available health records have been imported.',
      );
    });
  }

  Future<void> syncIfAuthorized() async {
    if (state.isLoading) return;
    final previous = state.valueOrNull;
    final granted = await _repository.grantedTypes();
    if (granted.isEmpty) {
      state = AsyncData(HealthConnectionState(
        authorized: false,
        lastSnapshot: previous?.lastSnapshot,
        message:
            'Health Connect permission is needed once to enable automatic sync.',
      ));
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _sync(
          granted,
          message: 'Health Connect synced automatically.',
        ));
  }

  Future<HealthConnectionState> _sync(
    List<HealthDataType> grantedTypes, {
    required String message,
  }) async {
    await ref.read(recoveryControllerProvider.future);
    final snapshot = await _repository.readLatest(grantedTypes);
    await ref
        .read(recoveryControllerProvider.notifier)
        .applyHealthSnapshot(snapshot);
    await ref
        .read(activityImportControllerProvider.notifier)
        .importHealthWorkouts(snapshot.workouts);
    if (snapshot.bodyMeasurements.isNotEmpty) {
      await ref
          .read(bodyMeasurementRepositoryProvider)
          .replaceHealthMeasurements(
            snapshot.bodyMeasurements.map(
              (value) => BodyMetric(
                measuredAt: value.measuredAt,
                weightKg: value.weightKg,
                bodyFatPercent: value.bodyFatPercent,
                source: 'healthConnect:${value.source}',
              ),
            ),
            since: DateTime.now().subtract(const Duration(days: 31)),
          );
    }
    if (snapshot.bodyMeasurements.isNotEmpty) {
      final latest = [...snapshot.bodyMeasurements]
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      final athleteController = ref.read(athleteProfileControllerProvider);
      final profile = await athleteController.load();
      await athleteController.save(
        profile.copyWith(weightKg: latest.first.weightKg),
      );
    }
    return HealthConnectionState(
      authorized: true,
      lastSnapshot: snapshot,
      message: message,
    );
  }
}
