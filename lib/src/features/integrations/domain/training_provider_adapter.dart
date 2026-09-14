enum TrainingProviderCapability {
  activitiesRead,
  wellnessRead,
  calendarWrite,
  webhooks,
}

class ProviderActivity {
  const ProviderActivity({
    required this.externalId,
    required this.startedAt,
    required this.durationSeconds,
    this.distanceMetres,
    this.averagePower,
    this.averageHeartRate,
    this.trainingLoad,
  });

  final String externalId;
  final DateTime startedAt;
  final int durationSeconds;
  final double? distanceMetres;
  final int? averagePower;
  final int? averageHeartRate;
  final double? trainingLoad;
}

class ProviderWellness {
  const ProviderWellness({
    required this.day,
    this.sleepMinutes,
    this.hrvMilliseconds,
    this.restingHeartRate,
    this.weightKg,
  });

  final DateTime day;
  final int? sleepMinutes;
  final double? hrvMilliseconds;
  final double? restingHeartRate;
  final double? weightKg;
}

class ProviderSyncBatch {
  const ProviderSyncBatch({
    this.activities = const [],
    this.wellness = const [],
    this.nextCursor,
  });

  final List<ProviderActivity> activities;
  final List<ProviderWellness> wellness;
  final String? nextCursor;
}

abstract interface class TrainingProviderAdapter {
  String get id;
  Set<TrainingProviderCapability> get capabilities;
  Future<bool> isConnected();
  Future<ProviderSyncBatch> fetchChanges({String? cursor});
}

class ProviderSyncResult {
  const ProviderSyncResult({
    required this.provider,
    required this.connected,
    required this.activityCount,
    required this.wellnessCount,
    this.nextCursor,
    this.error,
  });

  final String provider;
  final bool connected;
  final int activityCount;
  final int wellnessCount;
  final String? nextCursor;
  final Object? error;
}

class TrainingProviderSyncOrchestrator {
  TrainingProviderSyncOrchestrator(Iterable<TrainingProviderAdapter> adapters)
      : adapters = List.unmodifiable(adapters) {
    final ids = this.adapters.map((adapter) => adapter.id).toSet();
    if (ids.length != this.adapters.length) {
      throw ArgumentError('Training provider IDs must be unique.');
    }
  }

  final List<TrainingProviderAdapter> adapters;

  Future<List<ProviderSyncResult>> fetchAll({
    Map<String, String?> cursors = const {},
  }) async {
    return Future.wait(adapters.map((adapter) async {
      try {
        if (!await adapter.isConnected()) {
          return ProviderSyncResult(
            provider: adapter.id,
            connected: false,
            activityCount: 0,
            wellnessCount: 0,
          );
        }
        final batch = await adapter.fetchChanges(cursor: cursors[adapter.id]);
        _validateCapabilities(adapter, batch);
        return ProviderSyncResult(
          provider: adapter.id,
          connected: true,
          activityCount: batch.activities.length,
          wellnessCount: batch.wellness.length,
          nextCursor: batch.nextCursor,
        );
      } catch (error) {
        return ProviderSyncResult(
          provider: adapter.id,
          connected: true,
          activityCount: 0,
          wellnessCount: 0,
          error: error,
        );
      }
    }));
  }

  void _validateCapabilities(
    TrainingProviderAdapter adapter,
    ProviderSyncBatch batch,
  ) {
    if (batch.activities.isNotEmpty &&
        !adapter.capabilities
            .contains(TrainingProviderCapability.activitiesRead)) {
      throw StateError('${adapter.id} returned undeclared activity data.');
    }
    if (batch.wellness.isNotEmpty &&
        !adapter.capabilities
            .contains(TrainingProviderCapability.wellnessRead)) {
      throw StateError('${adapter.id} returned undeclared wellness data.');
    }
  }
}
