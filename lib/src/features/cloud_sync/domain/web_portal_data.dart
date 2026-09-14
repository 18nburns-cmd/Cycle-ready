import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_snapshot.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/relational_coaching_data.dart';

class WebPortalData {
  WebPortalData({
    required this.activities,
    required this.recovery,
    required this.body,
    required this.planned,
    required this.nutrition,
    required this.nutritionTargets,
    required this.ftpHistory,
    required this.athlete,
    required this.updatedAt,
  });

  factory WebPortalData.fromSnapshot(CloudSnapshot snapshot) => WebPortalData(
        activities: _rows(snapshot.payload, 'activities')
            .map(WebActivity.fromJson)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
        recovery: _rows(snapshot.payload, 'dailyRecovery')
            .map(WebRecoveryDay.fromJson)
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day)),
        body: _rows(snapshot.payload, 'bodyMeasurements')
            .map(WebBodyMeasurement.fromJson)
            .toList()
          ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt)),
        planned: _rows(snapshot.payload, 'plannedSessions')
            .map(WebPlannedSession.fromJson)
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day)),
        nutrition: _rows(snapshot.payload, 'nutritionEntries')
            .map(WebNutritionEntry.fromJson)
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
        nutritionTargets: _rows(snapshot.payload, 'dailyNutritionTargets')
            .map(WebNutritionTarget.fromJson)
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day)),
        ftpHistory: _rows(snapshot.payload, 'ftpEstimates')
            .map(WebFtpEstimate.fromJson)
            .toList()
          ..sort((a, b) => b.estimatedAt.compareTo(a.estimatedAt)),
        athlete: _rows(snapshot.payload, 'athleteSettings').isEmpty
            ? const <String, Object?>{}
            : _rows(snapshot.payload, 'athleteSettings').first,
        updatedAt: snapshot.updatedAt,
      );

  factory WebPortalData.fromRelational(RelationalCoachingData data) =>
      WebPortalData(
        activities: data.activities
            .map((row) => WebActivity.fromJson({
                  'id': row['id'],
                  'title': _sourceTitle(row['source_payload']) ??
                      row['sport'] ??
                      'Cycling activity',
                  'startedAt': row['started_at'],
                  'durationSeconds': row['duration_seconds'],
                  'distanceMetres': row['distance_metres'],
                  'elevationMetres': row['elevation_metres'],
                  'averagePower': row['average_power'],
                  'normalisedPower': row['normalized_power'],
                  'averageHeartRate': row['average_hr'],
                  'averageCadence': row['average_cadence'],
                  'trainingLoad': row['training_load'],
                }))
            .toList(growable: false),
        recovery: data.wellness
            .map((row) => WebRecoveryDay.fromJson({
                  'day': row['recorded_date'],
                  'sleepMinutes': row['sleep_minutes'],
                  'sleepQuality': row['sleep_quality'],
                  'restingHeartRate': row['resting_hr'],
                  'hrvMilliseconds': row['hrv_ms'],
                  'fatigue': row['fatigue'],
                  'soreness': row['soreness'],
                  'stress': row['stress'],
                  'motivation': row['motivation'],
                }))
            .toList(growable: false),
        body: data.weights
            .map((row) => WebBodyMeasurement.fromJson({
                  'measuredAt': row['measured_at'],
                  'weightKg': row['weight_kg'],
                }))
            .toList(growable: false),
        planned: data.plannedSessions
            .map((row) => WebPlannedSession.fromJson({
                  'day': row['scheduled_date'],
                  'title': row['purpose'] ?? row['session_type'],
                  'sessionType': row['session_type'],
                  'durationMinutes': row['planned_duration_minutes'],
                  'targetLoad': row['planned_load'],
                  'prescription': row['primary_adaptation'],
                  'adaptationReason': row['adaptation_status'],
                }))
            .toList(growable: false),
        nutrition: data.nutritionEntries
            .map((row) => WebNutritionEntry.fromJson({
                  'recordedAt': row['recorded_at'],
                  'label': row['label'],
                  'calories': row['calories'],
                  'carbohydrateGrams': row['carbohydrate_grams'],
                  'proteinGrams': row['protein_grams'],
                  'fatGrams': row['fat_grams'],
                  'waterMillilitres': row['water_millilitres'],
                }))
            .toList(growable: false),
        nutritionTargets: data.nutritionTargets
            .map((row) => WebNutritionTarget.fromJson({
                  'day': row['target_date'],
                  'calories': row['calories'],
                  'carbohydrateGrams': row['carbohydrate_grams'],
                  'proteinGrams': row['protein_grams'],
                  'fatGrams': row['fat_grams'],
                  'waterMillilitres': row['water_millilitres'],
                }))
            .toList(growable: false),
        ftpHistory: data.ftpHistory
            .map((row) => WebFtpEstimate.fromJson({
                  'estimatedAt': row['effective_date'],
                  'watts': row['ftp'],
                  'confidence': row['confidence'],
                }))
            .toList(growable: false),
        athlete: {
          'ftp': data.athlete['current_ftp'],
          'maximumHeartRate': data.athlete['maximum_hr'],
          'weightKg': data.athlete['body_mass_kg'],
        },
        updatedAt: data.updatedAt,
      );

  final List<WebActivity> activities;
  final List<WebRecoveryDay> recovery;
  final List<WebBodyMeasurement> body;
  final List<WebPlannedSession> planned;
  final List<WebNutritionEntry> nutrition;
  final List<WebNutritionTarget> nutritionTargets;
  final List<WebFtpEstimate> ftpHistory;
  final Map<String, Object?> athlete;
  final DateTime updatedAt;

  int? get ftp => _nullableNumber(athlete['ftp'])?.round();
  int? get maximumHeartRate =>
      _nullableNumber(athlete['maximumHeartRate'])?.round();
  double? get currentWeight => body.isNotEmpty
      ? body.first.weightKg
      : _nullableNumber(athlete['weightKg']);
  double? get powerToWeight =>
      ftp == null || currentWeight == null ? null : ftp! / currentWeight!;

  List<WebActivity> activitiesSince(Duration duration, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(duration);
    return activities
        .where((ride) => !ride.startedAt.isBefore(cutoff))
        .toList();
  }

  WebNutritionProgress nutritionFor(DateTime day) {
    final entries = nutrition.where((entry) => _sameDay(entry.recordedAt, day));
    final targets =
        nutritionTargets.where((target) => _sameDay(target.day, day));
    return WebNutritionProgress(
      calories: entries.fold(0, (sum, item) => sum + item.calories),
      carbohydrateGrams:
          entries.fold(0, (sum, item) => sum + item.carbohydrateGrams),
      proteinGrams: entries.fold(0, (sum, item) => sum + item.proteinGrams),
      fatGrams: entries.fold(0, (sum, item) => sum + item.fatGrams),
      waterMillilitres:
          entries.fold(0, (sum, item) => sum + item.waterMillilitres),
      target: targets.isEmpty ? null : targets.first,
    );
  }
}

class WebActivity {
  const WebActivity({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMetres,
    required this.elevationMetres,
    required this.averagePower,
    required this.normalisedPower,
    required this.averageHeartRate,
    required this.averageCadence,
    required this.trainingLoad,
  });

  factory WebActivity.fromJson(Map<String, Object?> row) => WebActivity(
        id: '${row['id'] ?? ''}',
        title: '${row['title'] ?? 'Activity'}',
        startedAt: _date(row['startedAt']),
        durationSeconds: _number(row['durationSeconds']).round(),
        distanceMetres: _number(row['distanceMetres']),
        elevationMetres: _number(row['elevationMetres']),
        averagePower: _nullableNumber(row['averagePower'])?.round(),
        normalisedPower: _nullableNumber(row['normalisedPower'])?.round(),
        averageHeartRate: _nullableNumber(row['averageHeartRate'])?.round(),
        averageCadence: _nullableNumber(row['averageCadence'])?.round(),
        trainingLoad: _nullableNumber(row['trainingLoad']) ?? 0,
      );

  final String id;
  final String title;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final double elevationMetres;
  final int? averagePower;
  final int? normalisedPower;
  final int? averageHeartRate;
  final int? averageCadence;
  final double trainingLoad;
}

class WebRecoveryDay {
  const WebRecoveryDay({
    required this.day,
    required this.sleepMinutes,
    required this.sleepQuality,
    required this.restingHeartRate,
    required this.hrvMilliseconds,
    required this.acuteTrainingLoad,
    required this.fatigue,
    required this.soreness,
    required this.stress,
    required this.motivation,
  });

  factory WebRecoveryDay.fromJson(Map<String, Object?> row) => WebRecoveryDay(
        day: _date(row['day']),
        sleepMinutes: _nullableNumber(row['sleepMinutes'])?.round(),
        sleepQuality: _nullableNumber(row['sleepQuality']),
        restingHeartRate: _nullableNumber(row['restingHeartRate']),
        hrvMilliseconds: _nullableNumber(row['hrvMilliseconds']),
        acuteTrainingLoad: _nullableNumber(row['acuteTrainingLoad']),
        fatigue: _nullableNumber(row['fatigue'])?.round(),
        soreness: _nullableNumber(row['soreness'])?.round(),
        stress: _nullableNumber(row['stress'])?.round(),
        motivation: _nullableNumber(row['motivation'])?.round(),
      );

  final DateTime day;
  final int? sleepMinutes;
  final double? sleepQuality;
  final double? restingHeartRate;
  final double? hrvMilliseconds;
  final double? acuteTrainingLoad;
  final int? fatigue;
  final int? soreness;
  final int? stress;
  final int? motivation;
}

class WebBodyMeasurement {
  const WebBodyMeasurement(this.measuredAt, this.weightKg, this.bodyFatPercent);
  factory WebBodyMeasurement.fromJson(Map<String, Object?> row) =>
      WebBodyMeasurement(
        _date(row['measuredAt']),
        _number(row['weightKg']),
        _nullableNumber(row['bodyFatPercent']),
      );
  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
}

class WebPlannedSession {
  const WebPlannedSession({
    required this.day,
    required this.title,
    required this.sessionType,
    required this.durationMinutes,
    required this.targetLoad,
    required this.prescription,
    required this.adaptationReason,
  });
  factory WebPlannedSession.fromJson(Map<String, Object?> row) =>
      WebPlannedSession(
        day: _date(row['day']),
        title: '${row['title'] ?? 'Planned session'}',
        sessionType: '${row['sessionType'] ?? 'cycling'}',
        durationMinutes: _number(row['durationMinutes']).round(),
        targetLoad: _number(row['targetLoad']).round(),
        prescription: '${row['prescription'] ?? ''}',
        adaptationReason: '${row['adaptationReason'] ?? ''}',
      );
  final DateTime day;
  final String title;
  final String sessionType;
  final int durationMinutes;
  final int targetLoad;
  final String prescription;
  final String adaptationReason;
}

class WebNutritionEntry {
  const WebNutritionEntry({
    required this.recordedAt,
    required this.label,
    required this.calories,
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.waterMillilitres,
  });
  factory WebNutritionEntry.fromJson(Map<String, Object?> row) =>
      WebNutritionEntry(
        recordedAt: _date(row['recordedAt']),
        label: '${row['label'] ?? 'Food'}',
        calories: _number(row['calories']).round(),
        carbohydrateGrams: _number(row['carbohydrateGrams']),
        proteinGrams: _number(row['proteinGrams']),
        fatGrams: _number(row['fatGrams']),
        waterMillilitres: _number(row['waterMillilitres']).round(),
      );
  final DateTime recordedAt;
  final String label;
  final int calories;
  final double carbohydrateGrams;
  final double proteinGrams;
  final double fatGrams;
  final int waterMillilitres;
}

class WebNutritionTarget {
  const WebNutritionTarget({
    required this.day,
    required this.calories,
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.waterMillilitres,
  });
  factory WebNutritionTarget.fromJson(Map<String, Object?> row) =>
      WebNutritionTarget(
        day: _date(row['day']),
        calories: _number(row['calories']).round(),
        carbohydrateGrams: _number(row['carbohydrateGrams']).round(),
        proteinGrams: _number(row['proteinGrams']).round(),
        fatGrams: _number(row['fatGrams']).round(),
        waterMillilitres: _number(row['waterMillilitres']).round(),
      );
  final DateTime day;
  final int calories;
  final int carbohydrateGrams;
  final int proteinGrams;
  final int fatGrams;
  final int waterMillilitres;
}

class WebNutritionProgress {
  const WebNutritionProgress({
    required this.calories,
    required this.carbohydrateGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.waterMillilitres,
    required this.target,
  });
  final int calories;
  final double carbohydrateGrams;
  final double proteinGrams;
  final double fatGrams;
  final int waterMillilitres;
  final WebNutritionTarget? target;
}

class WebFtpEstimate {
  const WebFtpEstimate(this.estimatedAt, this.watts, this.confidence);
  factory WebFtpEstimate.fromJson(Map<String, Object?> row) => WebFtpEstimate(
        _date(row['estimatedAt']),
        _number(row['watts']).round(),
        '${row['confidence'] ?? 'unknown'}',
      );
  final DateTime estimatedAt;
  final int watts;
  final String confidence;
}

List<Map<String, Object?>> _rows(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry('$key', value)))
      .toList();
}

double _number(Object? value) => _nullableNumber(value) ?? 0;
double? _nullableNumber(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
DateTime _date(Object? value) =>
    value is DateTime ? value : DateTime.tryParse('$value') ?? DateTime(1970);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String? _sourceTitle(Object? value) {
  if (value is! Map) return null;
  final title = value['name'] ?? value['title'];
  return title == null || '$title'.trim().isEmpty ? null : '$title';
}
