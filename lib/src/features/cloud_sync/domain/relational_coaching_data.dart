class RelationalCoachingData {
  const RelationalCoachingData({
    required this.athlete,
    required this.activities,
    required this.wellness,
    required this.weights,
    required this.plannedSessions,
    required this.ftpHistory,
    required this.nutritionEntries,
    required this.nutritionTargets,
    required this.latestReadiness,
    required this.latestDecision,
    required this.updatedAt,
  });

  final Map<String, Object?> athlete;
  final List<Map<String, Object?>> activities;
  final List<Map<String, Object?>> wellness;
  final List<Map<String, Object?>> weights;
  final List<Map<String, Object?>> plannedSessions;
  final List<Map<String, Object?>> ftpHistory;
  final List<Map<String, Object?>> nutritionEntries;
  final List<Map<String, Object?>> nutritionTargets;
  final Map<String, Object?>? latestReadiness;
  final AuthoritativeCoachingDecision? latestDecision;
  final DateTime updatedAt;
}

class AuthoritativeCoachingDecision {
  const AuthoritativeCoachingDecision({
    required this.id,
    required this.createdAt,
    required this.decision,
    required this.adaptationLevel,
    required this.reasonCodes,
    required this.explanation,
    required this.confidence,
    required this.originalWorkout,
    required this.replacementWorkout,
    required this.modelVersion,
  });

  factory AuthoritativeCoachingDecision.fromJson(Map<String, Object?> json) {
    Map<String, Object?> object(Object? value) => value is Map
        ? value.map((key, value) => MapEntry('$key', value))
        : const {};
    return AuthoritativeCoachingDecision(
      id: '${json['id'] ?? ''}',
      createdAt: DateTime.parse('${json['created_at']}').toUtc(),
      decision: '${json['decision'] ?? 'KEEP'}',
      adaptationLevel: _number(json['adaptation_level']).round(),
      reasonCodes: (json['reason_codes'] as List?)
              ?.map((value) => '$value')
              .toList(growable: false) ??
          const [],
      explanation: '${json['explanation'] ?? ''}',
      confidence: _number(json['confidence']),
      originalWorkout: object(json['original_workout']),
      replacementWorkout: json['replacement_workout'] == null
          ? null
          : object(json['replacement_workout']),
      modelVersion: '${json['coaching_model_version'] ?? ''}',
    );
  }

  final String id;
  final DateTime createdAt;
  final String decision;
  final int adaptationLevel;
  final List<String> reasonCodes;
  final String explanation;
  final double confidence;
  final Map<String, Object?> originalWorkout;
  final Map<String, Object?>? replacementWorkout;
  final String modelVersion;
}

abstract interface class RelationalCoachingRepository {
  Future<RelationalCoachingData> fetch();
}

double _number(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
