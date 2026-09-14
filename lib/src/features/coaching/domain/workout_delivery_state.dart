enum WorkoutDeliveryStatus {
  pending,
  delivered,
  updated,
  deleted,
  failed,
  externallyDiverged,
}

class WorkoutDeliveryState {
  const WorkoutDeliveryState({
    required this.plannedSessionId,
    required this.provider,
    required this.status,
    required this.updatedAt,
    this.externalWorkoutId,
    this.desiredContentHash,
    this.acknowledgedContentHash,
    this.desiredVersion = 1,
    this.acknowledgedVersion,
    this.attemptCount = 0,
    this.failureMessage,
  })  : assert(desiredVersion > 0),
        assert(attemptCount >= 0),
        assert(acknowledgedVersion == null ||
            (acknowledgedVersion > 0 && acknowledgedVersion <= desiredVersion));

  factory WorkoutDeliveryState.pending({
    required String plannedSessionId,
    required String provider,
    required DateTime now,
  }) =>
      WorkoutDeliveryState(
        plannedSessionId: plannedSessionId,
        provider: provider,
        status: WorkoutDeliveryStatus.pending,
        updatedAt: now,
      );

  final String plannedSessionId;
  final String provider;
  final WorkoutDeliveryStatus status;
  final DateTime updatedAt;
  final String? externalWorkoutId;
  final String? desiredContentHash;
  final String? acknowledgedContentHash;
  final int desiredVersion;
  final int? acknowledgedVersion;
  final int attemptCount;
  final String? failureMessage;

  bool get canRetry => status == WorkoutDeliveryStatus.failed;
  bool get needsAttention =>
      status == WorkoutDeliveryStatus.failed ||
      status == WorkoutDeliveryStatus.externallyDiverged;

  WorkoutDeliveryState transitionTo(
    WorkoutDeliveryStatus next, {
    required DateTime now,
    String? externalWorkoutId,
    String? desiredContentHash,
    String? acknowledgedContentHash,
    int? desiredVersion,
    int? acknowledgedVersion,
    int? attemptCount,
    String? failureMessage,
  }) {
    if (!_allowedTransitions[status]!.contains(next)) {
      throw StateError(
          'Cannot change delivery from ${status.name} to ${next.name}.');
    }
    final resolvedExternalId = externalWorkoutId ?? this.externalWorkoutId;
    if ({WorkoutDeliveryStatus.delivered, WorkoutDeliveryStatus.updated}
            .contains(next) &&
        (resolvedExternalId == null || resolvedExternalId.trim().isEmpty)) {
      throw ArgumentError(
          'A delivered workout requires a provider workout ID.');
    }
    if (next == WorkoutDeliveryStatus.failed &&
        (failureMessage == null || failureMessage.trim().isEmpty)) {
      throw ArgumentError('A failed delivery requires an explanation.');
    }
    return WorkoutDeliveryState(
      plannedSessionId: plannedSessionId,
      provider: provider,
      status: next,
      updatedAt: now,
      externalWorkoutId: resolvedExternalId,
      desiredContentHash: desiredContentHash ?? this.desiredContentHash,
      acknowledgedContentHash:
          acknowledgedContentHash ?? this.acknowledgedContentHash,
      desiredVersion: desiredVersion ?? this.desiredVersion,
      acknowledgedVersion: acknowledgedVersion ?? this.acknowledgedVersion,
      attemptCount: attemptCount ?? this.attemptCount,
      failureMessage:
          next == WorkoutDeliveryStatus.failed ? failureMessage : null,
    );
  }
}

class CalendarWorkoutDeliveryState {
  const CalendarWorkoutDeliveryState({
    required this.day,
    required this.delivery,
  });

  factory CalendarWorkoutDeliveryState.fromJson(Map<String, dynamic> json) {
    final plan = Map<String, dynamic>.from(json['planned_sessions'] as Map);
    return CalendarWorkoutDeliveryState(
      day: DateTime.parse('${plan['scheduled_date']}'),
      delivery: WorkoutDeliveryState(
        plannedSessionId: '${json['planned_session_id']}',
        provider: '${json['provider']}',
        status: WorkoutDeliveryStatus.values.byName(
          '${json['delivery_status']}'
              .replaceAll('externally_diverged', 'externallyDiverged'),
        ),
        updatedAt: DateTime.parse('${json['updated_at']}'),
        externalWorkoutId: json['external_workout_id'] as String?,
        desiredContentHash: json['desired_content_hash'] as String?,
        acknowledgedContentHash: json['acknowledged_content_hash'] as String?,
        desiredVersion: (json['desired_version'] as num?)?.toInt() ?? 1,
        acknowledgedVersion: (json['acknowledged_version'] as num?)?.toInt(),
        attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
        failureMessage: json['failure_message'] as String?,
      ),
    );
  }

  final DateTime day;
  final WorkoutDeliveryState delivery;
}

abstract interface class WorkoutDeliveryStatusRepository {
  Future<List<CalendarWorkoutDeliveryState>> fetchRange(
    DateTime start,
    DateTime end,
  );
  Future<bool> retry(String plannedSessionId, {required String provider});
  Future<int> retryFuture({required String provider});
}

const _allowedTransitions = <WorkoutDeliveryStatus, Set<WorkoutDeliveryStatus>>{
  WorkoutDeliveryStatus.pending: {
    WorkoutDeliveryStatus.delivered,
    WorkoutDeliveryStatus.updated,
    WorkoutDeliveryStatus.deleted,
    WorkoutDeliveryStatus.failed,
  },
  WorkoutDeliveryStatus.delivered: {
    WorkoutDeliveryStatus.pending,
    WorkoutDeliveryStatus.updated,
    WorkoutDeliveryStatus.deleted,
    WorkoutDeliveryStatus.failed,
    WorkoutDeliveryStatus.externallyDiverged,
  },
  WorkoutDeliveryStatus.updated: {
    WorkoutDeliveryStatus.pending,
    WorkoutDeliveryStatus.updated,
    WorkoutDeliveryStatus.deleted,
    WorkoutDeliveryStatus.failed,
    WorkoutDeliveryStatus.externallyDiverged,
  },
  WorkoutDeliveryStatus.deleted: {},
  WorkoutDeliveryStatus.failed: {WorkoutDeliveryStatus.pending},
  WorkoutDeliveryStatus.externallyDiverged: {
    WorkoutDeliveryStatus.pending,
    WorkoutDeliveryStatus.deleted,
  },
};
