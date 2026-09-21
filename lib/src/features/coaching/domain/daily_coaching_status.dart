enum DailyCoachingRunStatus { neverRun, running, completed, failed, retrying }

class DailyCoachingStatus {
  const DailyCoachingStatus({
    required this.nextRunAt,
    required this.status,
    required this.attemptNumber,
    required this.timezone,
    this.lastRunAt,
    this.modelVersion,
    this.failureCode,
    this.failureMessage,
  });

  factory DailyCoachingStatus.fromJson(Map<String, dynamic> json) =>
      DailyCoachingStatus(
        lastRunAt: DateTime.tryParse('${json['last_run_at'] ?? ''}'),
        nextRunAt: DateTime.parse('${json['next_run_at']}'),
        modelVersion: json['model_version'] as String?,
        status: switch ('${json['status']}'.toUpperCase()) {
          'RUNNING' => DailyCoachingRunStatus.running,
          'COMPLETED' => DailyCoachingRunStatus.completed,
          'FAILED' => DailyCoachingRunStatus.failed,
          'RETRYING' => DailyCoachingRunStatus.retrying,
          _ => DailyCoachingRunStatus.neverRun,
        },
        failureCode: json['failure_code'] as String?,
        failureMessage: json['failure_message'] as String?,
        attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 0,
        timezone: '${json['timezone']}',
      );

  final DateTime? lastRunAt;
  final DateTime nextRunAt;
  final String? modelVersion;
  final DailyCoachingRunStatus status;
  final String? failureCode;
  final String? failureMessage;
  final int attemptNumber;
  final String timezone;
}

abstract interface class DailyCoachingStatusRepository {
  Future<DailyCoachingStatus> fetchStatus();
  Future<DailyCoachingRecommendation?> fetchToday();
}

class DailyCoachingRecommendation {
  const DailyCoachingRecommendation(
      {required this.date,
      required this.decision,
      required this.explanation,
      required this.confidence,
      required this.modelVersion,
      this.generatedAt,
      this.workout});

  factory DailyCoachingRecommendation.fromJson(Map<String, dynamic> row) {
    final payload = Map<String, dynamic>.from(row['recommendation'] as Map);
    final selected = payload['selected_workout'];
    return DailyCoachingRecommendation(
      date: DateTime.parse('${row['coaching_date']}'),
      decision: '${payload['decision']}',
      explanation: '${payload['explanation']}',
      confidence: (payload['confidence'] as num?)?.toDouble() ?? .45,
      modelVersion: '${payload['model_version'] ?? row['model_version']}',
      generatedAt: DateTime.tryParse(
        '${payload['generated_at'] ?? row['generated_at'] ?? ''}',
      ),
      workout: selected is Map
          ? DailyCoachingWorkout.fromJson(Map<String, dynamic>.from(selected))
          : null,
    );
  }

  factory DailyCoachingRecommendation.fromOutputJson(
    Map<String, dynamic> payload,
  ) =>
      DailyCoachingRecommendation.fromJson({
        'coaching_date': payload['coaching_date'],
        'model_version': payload['model_version'],
        'recommendation': payload,
      });

  final DateTime date;
  final String decision;
  final String explanation;
  final double confidence;
  final String modelVersion;
  final DateTime? generatedAt;
  final DailyCoachingWorkout? workout;
}

bool dailyCoachingRecommendationMatchesPlan({
  required DailyCoachingRecommendation recommendation,
  required String? plannedSessionType,
  required String? plannedTitle,
  required int? plannedDurationMinutes,
  required int? plannedTargetLoad,
}) {
  final workout = recommendation.workout;
  if (plannedSessionType == null) return workout == null;
  if (workout == null) {
    return recommendation.decision.toUpperCase() == 'REST' &&
        plannedSessionType == 'rest';
  }
  final normalizedFamily = workout.family.toLowerCase().replaceAll('-', '_');
  final normalizedType = switch (normalizedFamily) {
    'sweet_spot' => 'tempo',
    'threshold' ||
    'vo2_max' ||
    'anaerobic' ||
    'sprint' ||
    'race_simulation' =>
      'intervals',
    _ => normalizedFamily,
  };
  return normalizedType == plannedSessionType &&
      workout.title == plannedTitle &&
      workout.durationMinutes == plannedDurationMinutes &&
      workout.targetLoad == plannedTargetLoad;
}

class DailyCoachingWorkout {
  const DailyCoachingWorkout(
      {required this.title,
      required this.family,
      required this.durationMinutes,
      required this.targetLoad});

  factory DailyCoachingWorkout.fromJson(Map<String, dynamic> json) =>
      DailyCoachingWorkout(
        title: '${json['title'] ?? json['purpose'] ?? 'Today’s workout'}',
        family: '${json['family'] ?? json['session_type'] ?? 'endurance'}'
            .toLowerCase(),
        durationMinutes: (json['duration_minutes'] as num?)?.round() ?? 0,
        targetLoad: (json['target_load'] as num?)?.round() ??
            (json['planned_load'] as num?)?.round() ??
            0,
      );

  final String title;
  final String family;
  final int durationMinutes;
  final int targetLoad;
}
