import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('Cycling'))();
  TextColumn get source => text()();
  TextColumn get externalId => text().nullable()();
  TextColumn get fileHash => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
  RealColumn get distanceMetres => real()();
  RealColumn get elevationMetres => real().withDefault(const Constant(0))();
  IntColumn get averageHeartRate => integer().nullable()();
  IntColumn get maximumHeartRate => integer().nullable()();
  IntColumn get averagePower => integer().nullable()();
  IntColumn get maximumPower => integer().nullable()();
  IntColumn get normalisedPower => integer().nullable()();
  IntColumn get averageCadence => integer().nullable()();
  IntColumn get calories => integer().nullable()();
  IntColumn get trainingLoad => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ActivitySamples extends Table {
  TextColumn get activityId => text().references(Activities, #id)();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get heartRate => integer().nullable()();
  IntColumn get power => integer().nullable()();
  IntColumn get cadence => integer().nullable()();
  RealColumn get altitudeMetres => real().nullable()();
  RealColumn get distanceMetres => real().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {activityId, elapsedSeconds};
}

class AthleteSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get athleteName => text().withDefault(const Constant('Neil'))();
  IntColumn get age => integer().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get experienceLevel =>
      text().withDefault(const Constant('intermediate'))();
  TextColumn get bikeDetails => text().withDefault(const Constant(''))();
  TextColumn get equipment => text().withDefault(const Constant(''))();
  BoolColumn get hasPowerMeter => boolean().withDefault(const Constant(true))();
  BoolColumn get hasIndoorTrainer =>
      boolean().withDefault(const Constant(true))();
  IntColumn get preferredRideTimeMinutes =>
      integer().withDefault(const Constant(18 * 60))();
  TextColumn get nutritionPreferences =>
      text().withDefault(const Constant(''))();
  TextColumn get injuryHistory => text().withDefault(const Constant(''))();
  TextColumn get trainingLocation => text().withDefault(const Constant(''))();
  TextColumn get ridingSafetyProfile =>
      text().withDefault(const Constant('balanced'))();
  IntColumn get ftp => integer().withDefault(const Constant(200))();
  IntColumn get thresholdHeartRate => integer().nullable()();
  IntColumn get maximumHeartRate =>
      integer().withDefault(const Constant(190))();
  IntColumn get restingHeartRate => integer().withDefault(const Constant(50))();
  RealColumn get weightKg => real().withDefault(const Constant(70))();
  IntColumn get weeklyLoadTarget =>
      integer().withDefault(const Constant(350))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DailyRecoveryRecords extends Table {
  DateTimeColumn get day => dateTime()();
  IntColumn get sleepMinutes => integer().nullable()();
  DateTimeColumn get sleepEndedAt => dateTime().nullable()();
  RealColumn get sleepQuality => real().nullable()();
  RealColumn get restingHeartRate => real().nullable()();
  RealColumn get hrvMilliseconds => real().nullable()();
  RealColumn get acuteTrainingLoad => real().nullable()();
  IntColumn get fatigue => integer().nullable()();
  IntColumn get soreness => integer().nullable()();
  IntColumn get stress => integer().nullable()();
  IntColumn get motivation => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

class BodyMeasurements extends Table {
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get weightKg => real()();
  RealColumn get bodyFatPercent => real().nullable()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {measuredAt, source};
}

class PlannedSessions extends Table {
  DateTimeColumn get day => dateTime()();
  TextColumn get sessionType => text()();
  TextColumn get title => text()();
  IntColumn get durationMinutes => integer()();
  IntColumn get targetLoad => integer()();
  BoolColumn get confirmed => boolean().withDefault(const Constant(false))();
  TextColumn get prescription => text().withDefault(const Constant(''))();
  TextColumn get origin => text().withDefault(const Constant('manual'))();
  TextColumn get adaptationReason => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

class FtpEstimates extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get estimatedAt => dateTime()();
  DateTimeColumn get windowStart => dateTime()();
  IntColumn get watts => integer()();
  IntColumn get lowWatts => integer()();
  IntColumn get highWatts => integer()();
  TextColumn get confidence => text()();
  IntColumn get rideCount => integer()();
  IntColumn get durationCoverage => integer()();
  BoolColumn get accepted => boolean().withDefault(const Constant(false))();
}

class TrainingPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get goal => text().withDefault(const Constant('generalFitness'))();
  IntColumn get daysPerWeek => integer().withDefault(const Constant(4))();
  IntColumn get longRideWeekday => integer().withDefault(const Constant(6))();
  TextColumn get availabilityJson => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class EventGoals extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text()();
  DateTimeColumn get eventDate => dateTime()();
  RealColumn get distanceKm => real()();
  IntColumn get elevationMetres => integer()();
  TextColumn get priority => text().withDefault(const Constant('A'))();
  TextColumn get target => text().withDefault(const Constant('finishStrong'))();
  TextColumn get terrain => text().withDefault(const Constant('rolling'))();
  IntColumn get availableDays => integer().withDefault(const Constant(4))();
  IntColumn get longRideMinutes => integer().withDefault(const Constant(180))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NutritionEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get label => text().withDefault(const Constant('Food'))();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  RealColumn get carbohydrateGrams => real().withDefault(const Constant(0))();
  RealColumn get proteinGrams => real().withDefault(const Constant(0))();
  RealColumn get fatGrams => real().withDefault(const Constant(0))();
  IntColumn get waterMillilitres => integer().withDefault(const Constant(0))();
}

class DailyNutritionTargets extends Table {
  DateTimeColumn get day => dateTime()();
  IntColumn get calories => integer()();
  IntColumn get carbohydrateGrams => integer()();
  IntColumn get proteinGrams => integer()();
  IntColumn get fatGrams => integer()();
  IntColumn get waterMillilitres => integer()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

class PostRideFeedbacks extends Table {
  TextColumn get activityId => text().references(Activities, #id)();
  IntColumn get perceivedEffort => integer()();
  IntColumn get legFatigue => integer()();
  IntColumn get enjoyment => integer()();
  IntColumn get discomfort => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {activityId};
}

class RideCoachReports extends Table {
  TextColumn get activityId => text().references(Activities, #id)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get plannedTitle => text().nullable()();
  RealColumn get executionScore => real()();
  TextColumn get objective => text()();
  TextColumn get summary => text()();
  TextColumn get execution => text()();
  TextColumn get tomorrowRecommendation => text()();
  TextColumn get keyFocus => text()();
  TextColumn get confidence => text()();
  TextColumn get confidenceReason => text()();

  @override
  Set<Column<Object>> get primaryKey => {activityId};
}

class SavedFoods extends Table {
  TextColumn get name => text()();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  RealColumn get carbohydrateGrams => real().withDefault(const Constant(0))();
  RealColumn get proteinGrams => real().withDefault(const Constant(0))();
  RealColumn get fatGrams => real().withDefault(const Constant(0))();
  IntColumn get waterMillilitres => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

class StrengthProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get goal => text()();
  TextColumn get location => text()();
  TextColumn get experience => text()();
  IntColumn get daysPerWeek => integer()();
  IntColumn get sessionMinutes => integer()();
  TextColumn get equipment => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StrengthSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get routineName => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class StrengthSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(StrengthSessions, #id)();
  TextColumn get exerciseId => text()();
  IntColumn get setNumber => integer()();
  IntColumn get targetReps => integer()();
  IntColumn get completedReps => integer().withDefault(const Constant(0))();
  RealColumn get weightKg => real().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class CoachingDecisions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get scheduledDay => dateTime()();
  TextColumn get workoutType => text()();
  TextColumn get title => text()();
  TextColumn get reason => text()();
  IntColumn get readiness => integer()();
  RealColumn get fitness => real()();
  RealColumn get fatigue => real()();
  RealColumn get form => real()();
  IntColumn get targetLoad => integer()();
  RealColumn get confidence => real().withDefault(const Constant(.7))();
  BoolColumn get outcomeProcessed =>
      boolean().withDefault(const Constant(false))();
}

class WorkoutResponseProfiles extends Table {
  TextColumn get workoutType => text()();
  IntColumn get sampleCount => integer().withDefault(const Constant(0))();
  RealColumn get averageLoadRatio => real().withDefault(const Constant(1))();
  RealColumn get averageDurationRatio =>
      real().withDefault(const Constant(1))();
  RealColumn get completionRate => real().withDefault(const Constant(0))();
  IntColumn get feedbackSamples => integer().withDefault(const Constant(0))();
  RealColumn get averagePerceivedEffort =>
      real().withDefault(const Constant(0))();
  RealColumn get averageLegFatigue => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {workoutType};
}

@DriftDatabase(tables: [
  Activities,
  ActivitySamples,
  AthleteSettings,
  DailyRecoveryRecords,
  BodyMeasurements,
  PlannedSessions,
  FtpEstimates,
  TrainingPreferences,
  EventGoals,
  NutritionEntries,
  DailyNutritionTargets,
  PostRideFeedbacks,
  RideCoachReports,
  SavedFoods,
  StrengthProfiles,
  StrengthSessions,
  StrengthSets,
  CoachingDecisions,
  WorkoutResponseProfiles,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(activities, activities.title);
            await m.addColumn(activities, activities.fileHash);
            await m.addColumn(activities, activities.averageHeartRate);
            await m.addColumn(activities, activities.maximumHeartRate);
            await m.addColumn(activities, activities.averagePower);
            await m.addColumn(activities, activities.maximumPower);
            await m.addColumn(activities, activities.normalisedPower);
            await m.addColumn(activities, activities.averageCadence);
            await m.addColumn(activities, activities.calories);
            await m.createTable(activitySamples);
            await m.createTable(athleteSettings);
          }
          if (from < 3) {
            await m.createTable(plannedSessions);
          }
          if (from < 4) {
            await m.createTable(ftpEstimates);
          }
          if (from < 5) {
            await m.addColumn(plannedSessions, plannedSessions.prescription);
            await m.createTable(trainingPreferences);
          }
          if (from < 6) {
            await m.addColumn(activitySamples, activitySamples.latitude);
            await m.addColumn(activitySamples, activitySamples.longitude);
          }
          if (from < 7) {
            await m.createTable(nutritionEntries);
            await m.createTable(dailyNutritionTargets);
          }
          if (from < 8) {
            await m.createTable(postRideFeedbacks);
          }
          if (from < 9) {
            await m.createTable(savedFoods);
          }
          if (from < 10) {
            await m.addColumn(
              dailyRecoveryRecords,
              dailyRecoveryRecords.sleepEndedAt,
            );
          }
          if (from < 11) {
            await m.createTable(strengthProfiles);
            await m.createTable(strengthSessions);
            await m.createTable(strengthSets);
          }
          if (from < 12) {
            await m.addColumn(plannedSessions, plannedSessions.origin);
            await m.addColumn(
              plannedSessions,
              plannedSessions.adaptationReason,
            );
          }
          if (from < 13) {
            await m.createTable(eventGoals);
          }
          if (from < 14) {
            await m.addColumn(
              trainingPreferences,
              trainingPreferences.availabilityJson,
            );
          }
          if (from < 15) {
            await m.createTable(coachingDecisions);
            await m.createTable(workoutResponseProfiles);
          }
          if (from < 16) {
            await m.addColumn(athleteSettings, athleteSettings.athleteName);
            await m.addColumn(athleteSettings, athleteSettings.age);
            await m.addColumn(athleteSettings, athleteSettings.heightCm);
            await m.addColumn(
              athleteSettings,
              athleteSettings.experienceLevel,
            );
            await m.addColumn(
              athleteSettings,
              athleteSettings.thresholdHeartRate,
            );
          }
          if (from < 17) {
            await m.createTable(rideCoachReports);
          }
          if (from < 18) {
            await m.addColumn(athleteSettings, athleteSettings.bikeDetails);
            await m.addColumn(athleteSettings, athleteSettings.equipment);
            await m.addColumn(athleteSettings, athleteSettings.hasPowerMeter);
            await m.addColumn(
              athleteSettings,
              athleteSettings.hasIndoorTrainer,
            );
            await m.addColumn(
              athleteSettings,
              athleteSettings.preferredRideTimeMinutes,
            );
            await m.addColumn(
              athleteSettings,
              athleteSettings.nutritionPreferences,
            );
            await m.addColumn(athleteSettings, athleteSettings.injuryHistory);
          }
          if (from < 19) {
            await m.addColumn(
                athleteSettings, athleteSettings.trainingLocation);
          }
          if (from < 20) {
            await m.addColumn(
              athleteSettings,
              athleteSettings.ridingSafetyProfile,
            );
          }
        },
      );

  Future<DailyRecoveryRecord?> recoveryForDay(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (select(dailyRecoveryRecords)..where((row) => row.day.equals(day)))
        .getSingleOrNull();
  }

  Future<List<DailyRecoveryRecord>> getRecoveryRecords(
    DateTime start,
    DateTime end,
  ) =>
      (select(dailyRecoveryRecords)
            ..where(
              (row) =>
                  row.day.isBiggerOrEqualValue(start) &
                  row.day.isSmallerThanValue(end),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.day)]))
          .get();

  Future<void> saveRecovery(DailyRecoveryRecordsCompanion record) {
    return into(dailyRecoveryRecords).insertOnConflictUpdate(record);
  }

  Stream<DateTime?> watchLatestSleepEnd() => (select(dailyRecoveryRecords)
        ..where((row) => row.sleepEndedAt.isNotNull())
        ..orderBy([(row) => OrderingTerm.desc(row.sleepEndedAt)])
        ..limit(1))
      .watchSingleOrNull()
      .map((record) => record?.sleepEndedAt);

  Future<void> saveBodyMeasurement(BodyMeasurementsCompanion record) {
    return into(bodyMeasurements).insertOnConflictUpdate(record);
  }

  Stream<List<BodyMeasurement>> watchBodyMeasurements() =>
      (select(bodyMeasurements)
            ..orderBy([(row) => OrderingTerm.asc(row.measuredAt)]))
          .watch();

  Future<void> saveBodyMeasurements(
      Iterable<BodyMeasurementsCompanion> records) async {
    final values = records.toList();
    if (values.isEmpty) return;
    await batch(
      (batch) => batch.insertAllOnConflictUpdate(bodyMeasurements, values),
    );
  }

  Future<void> replaceRecentHealthBodyMeasurements(
    Iterable<BodyMeasurementsCompanion> records, {
    required DateTime since,
  }) async {
    final values = records.toList();
    await transaction(() async {
      await (delete(bodyMeasurements)
            ..where((row) =>
                row.measuredAt.isBiggerOrEqualValue(since) &
                row.source.like('healthConnect:%')))
          .go();
      if (values.isNotEmpty) {
        await batch(
          (batch) => batch.insertAllOnConflictUpdate(bodyMeasurements, values),
        );
      }
    });
  }

  Stream<List<Activity>> watchActivities() =>
      (select(activities)..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .watch();

  Future<Activity?> activityById(String id) =>
      (select(activities)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<List<ActivitySample>> samplesFor(String id) => (select(activitySamples)
        ..where((row) => row.activityId.equals(id))
        ..orderBy([(row) => OrderingTerm.asc(row.elapsedSeconds)]))
      .get();

  Future<void> saveActivity(
    ActivitiesCompanion activity,
    List<ActivitySamplesCompanion> samples,
  ) =>
      transaction(() async {
        await into(activities).insertOnConflictUpdate(activity);
        if (samples.isNotEmpty) {
          await batch((batch) => batch.insertAllOnConflictUpdate(
                activitySamples,
                samples,
              ));
        }
      });

  Future<void> saveActivitySamples(
      List<ActivitySamplesCompanion> samples) async {
    if (samples.isEmpty) return;
    await batch(
        (batch) => batch.insertAllOnConflictUpdate(activitySamples, samples));
  }

  Future<bool> hasActivityMatch({
    String? externalId,
    String? fileHash,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    return await findActivityMatch(
          externalId: externalId,
          fileHash: fileHash,
          startedAt: startedAt,
          durationSeconds: durationSeconds,
        ) !=
        null;
  }

  Future<Activity?> findActivityMatch({
    String? externalId,
    String? fileHash,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    final rows = await (select(activities)
          ..where((row) =>
              (externalId != null
                  ? row.externalId.equals(externalId)
                  : const Constant(false)) |
              (fileHash != null
                  ? row.fileHash.equals(fileHash)
                  : const Constant(false)) |
              (row.startedAt.isBetweenValues(
                    startedAt.subtract(const Duration(minutes: 2)),
                    startedAt.add(const Duration(minutes: 2)),
                  ) &
                  row.durationSeconds.isBetweenValues(
                      durationSeconds - 120, durationSeconds + 120))))
        .get();
    return rows.firstOrNull;
  }

  Future<AthleteSetting> getAthleteSettings() async {
    final existing = await select(athleteSettings).getSingleOrNull();
    if (existing != null) return existing;
    await into(athleteSettings).insert(const AthleteSettingsCompanion());
    return select(athleteSettings).getSingle();
  }

  Stream<AthleteSetting?> watchAthleteSettings() =>
      select(athleteSettings).watchSingleOrNull();

  Future<void> saveAthleteSettings(AthleteSettingsCompanion value) =>
      into(athleteSettings).insertOnConflictUpdate(value);

  Stream<PlannedSession?> watchPlannedSession(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (select(plannedSessions)..where((row) => row.day.equals(day)))
        .watchSingleOrNull();
  }

  Stream<List<PlannedSession>> watchPlannedSessions(
      DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return (select(plannedSessions)
          ..where((row) => row.day.isBetweenValues(first, last))
          ..orderBy([(row) => OrderingTerm.asc(row.day)]))
        .watch();
  }

  Future<List<PlannedSession>> getPlannedSessions(
      DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return (select(plannedSessions)
          ..where((row) => row.day.isBetweenValues(first, last))
          ..orderBy([(row) => OrderingTerm.asc(row.day)]))
        .get();
  }

  Future<void> savePlannedSession(PlannedSessionsCompanion value) =>
      into(plannedSessions).insertOnConflictUpdate(value);

  Future<void> deletePlannedSession(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (delete(plannedSessions)..where((row) => row.day.equals(day))).go();
  }

  Future<void> deleteAdaptivePlannedSessions(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return (delete(plannedSessions)
          ..where((row) =>
              row.origin.equals('adaptive') &
              row.day.isBetweenValues(first, last)))
        .go();
  }

  Future<TrainingPreference> getTrainingPreferences() async {
    final existing = await select(trainingPreferences).getSingleOrNull();
    if (existing != null) return existing;
    await into(trainingPreferences)
        .insert(const TrainingPreferencesCompanion());
    return select(trainingPreferences).getSingle();
  }

  Stream<TrainingPreference?> watchTrainingPreferences() =>
      select(trainingPreferences).watchSingleOrNull();

  Future<void> saveTrainingPreferences(TrainingPreferencesCompanion value) =>
      into(trainingPreferences).insertOnConflictUpdate(value);

  Stream<EventGoal?> watchEventGoal() => select(eventGoals).watchSingleOrNull();

  Future<EventGoal?> getEventGoal() => select(eventGoals).getSingleOrNull();

  Future<void> saveEventGoal(EventGoalsCompanion value) =>
      into(eventGoals).insertOnConflictUpdate(value);

  Future<void> deleteEventGoal() => delete(eventGoals).go();

  Future<int> saveFtpEstimate(FtpEstimatesCompanion value) =>
      into(ftpEstimates).insert(value);

  Stream<List<FtpEstimate>> watchFtpEstimates() => (select(ftpEstimates)
        ..orderBy([(row) => OrderingTerm.desc(row.estimatedAt)]))
      .watch();

  Future<void> acceptFtpEstimate(FtpEstimate estimate) => transaction(() async {
        await (update(ftpEstimates)..where((row) => row.id.equals(estimate.id)))
            .write(const FtpEstimatesCompanion(accepted: Value(true)));
        final settings = await getAthleteSettings();
        await saveAthleteSettings(settings.toCompanion(true).copyWith(
              ftp: Value(estimate.watts),
            ));
      });

  Future<int> saveCoachingDecision(CoachingDecisionsCompanion value) =>
      into(coachingDecisions).insert(value);

  Stream<List<CoachingDecision>> watchCoachingDecisions({int limit = 100}) =>
      (select(coachingDecisions)
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
            ..limit(limit))
          .watch();

  Future<void> markCoachingDecisionsProcessed(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (update(coachingDecisions)
          ..where((row) => row.scheduledDay.equals(day)))
        .write(const CoachingDecisionsCompanion(
      outcomeProcessed: Value(true),
    ));
  }

  Future<bool> hasUnprocessedCoachingDecision(DateTime value) async {
    final day = DateTime(value.year, value.month, value.day);
    final decision = await (select(coachingDecisions)
          ..where((row) =>
              row.scheduledDay.equals(day) & row.outcomeProcessed.equals(false))
          ..limit(1))
        .getSingleOrNull();
    return decision != null;
  }

  Future<WorkoutResponseProfile?> workoutResponseProfile(String type) =>
      (select(workoutResponseProfiles)
            ..where((row) => row.workoutType.equals(type)))
          .getSingleOrNull();

  Stream<WorkoutResponseProfile?> watchWorkoutResponseProfile(String type) =>
      (select(workoutResponseProfiles)
            ..where((row) => row.workoutType.equals(type)))
          .watchSingleOrNull();

  Future<void> saveWorkoutResponseProfile(
          WorkoutResponseProfilesCompanion value) =>
      into(workoutResponseProfiles).insertOnConflictUpdate(value);

  Future<void> saveRideCoachReport(RideCoachReportsCompanion value) =>
      into(rideCoachReports).insertOnConflictUpdate(value);

  Stream<RideCoachReport?> watchRideCoachReport(String activityId) =>
      (select(rideCoachReports)
            ..where((row) => row.activityId.equals(activityId)))
          .watchSingleOrNull();

  Future<List<Activity>> getActivities() =>
      (select(activities)..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
          .get();

  Future<Map<String, Object?>> exportSnapshot() async => {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        'activities': (await select(activities).get())
            .map((row) => row.toJson())
            .toList(),
        'activitySamples': (await select(activitySamples).get())
            .map((row) => row.toJson())
            .toList(),
        'athleteSettings': (await select(athleteSettings).get())
            .map((row) => row.toJson())
            .toList(),
        'dailyRecovery': (await select(dailyRecoveryRecords).get())
            .map((row) => row.toJson())
            .toList(),
        'bodyMeasurements': (await select(bodyMeasurements).get())
            .map((row) => row.toJson())
            .toList(),
        'plannedSessions': (await select(plannedSessions).get())
            .map((row) => row.toJson())
            .toList(),
        'ftpEstimates': (await select(ftpEstimates).get())
            .map((row) => row.toJson())
            .toList(),
        'trainingPreferences': (await select(trainingPreferences).get())
            .map((row) => row.toJson())
            .toList(),
        'eventGoals': (await select(eventGoals).get())
            .map((row) => row.toJson())
            .toList(),
        'nutritionEntries': (await select(nutritionEntries).get())
            .map((row) => row.toJson())
            .toList(),
        'dailyNutritionTargets': (await select(dailyNutritionTargets).get())
            .map((row) => row.toJson())
            .toList(),
        'postRideFeedbacks': (await select(postRideFeedbacks).get())
            .map((row) => row.toJson())
            .toList(),
        'rideCoachReports': (await select(rideCoachReports).get())
            .map((row) => row.toJson())
            .toList(),
        'savedFoods': (await select(savedFoods).get())
            .map((row) => row.toJson())
            .toList(),
        'strengthProfiles': (await select(strengthProfiles).get())
            .map((row) => row.toJson())
            .toList(),
        'strengthSessions': (await select(strengthSessions).get())
            .map((row) => row.toJson())
            .toList(),
        'strengthSets': (await select(strengthSets).get())
            .map((row) => row.toJson())
            .toList(),
        'coachingDecisions': (await select(coachingDecisions).get())
            .map((row) => row.toJson())
            .toList(),
        'workoutResponseProfiles': (await select(workoutResponseProfiles).get())
            .map((row) => row.toJson())
            .toList(),
      };

  Future<void> restoreSnapshot(Map<String, dynamic> snapshot) async {
    final version = snapshot['schemaVersion'];
    if (version is! int || version < 1 || version > schemaVersion) {
      throw const FormatException('Unsupported CycleReady backup version.');
    }

    List<Map<String, dynamic>> rows(String key) {
      final value = snapshot[key];
      if (value == null) return const [];
      if (value is! List) {
        throw FormatException('Invalid $key section in backup.');
      }
      return value.map((row) {
        if (row is! Map) {
          throw FormatException('Invalid record in $key.');
        }
        return Map<String, dynamic>.from(row);
      }).toList();
    }

    // Decode every section before opening the transaction. A malformed backup
    // therefore cannot erase or partially replace the current database.
    final restoredActivities =
        rows('activities').map(Activity.fromJson).toList();
    final restoredSamples =
        rows('activitySamples').map(ActivitySample.fromJson).toList();
    final restoredSettings =
        rows('athleteSettings').map(AthleteSetting.fromJson).toList();
    final restoredRecovery =
        rows('dailyRecovery').map(DailyRecoveryRecord.fromJson).toList();
    final restoredBody =
        rows('bodyMeasurements').map(BodyMeasurement.fromJson).toList();
    final restoredPlans =
        rows('plannedSessions').map(PlannedSession.fromJson).toList();
    final restoredFtp = rows('ftpEstimates').map(FtpEstimate.fromJson).toList();
    final restoredPreferences =
        rows('trainingPreferences').map(TrainingPreference.fromJson).toList();
    final restoredEvents = rows('eventGoals').map(EventGoal.fromJson).toList();
    final restoredNutrition =
        rows('nutritionEntries').map(NutritionEntry.fromJson).toList();
    final restoredTargets = rows('dailyNutritionTargets')
        .map(DailyNutritionTarget.fromJson)
        .toList();
    final restoredFeedback =
        rows('postRideFeedbacks').map(PostRideFeedback.fromJson).toList();
    final restoredRideReports =
        rows('rideCoachReports').map(RideCoachReport.fromJson).toList();
    final restoredFoods = rows('savedFoods').map(SavedFood.fromJson).toList();
    final restoredProfiles =
        rows('strengthProfiles').map(StrengthProfile.fromJson).toList();
    final restoredStrengthSessions =
        rows('strengthSessions').map(StrengthSession.fromJson).toList();
    final restoredStrengthSets =
        rows('strengthSets').map(StrengthSet.fromJson).toList();
    final restoredDecisions =
        rows('coachingDecisions').map(CoachingDecision.fromJson).toList();
    final restoredResponses = rows('workoutResponseProfiles')
        .map(WorkoutResponseProfile.fromJson)
        .toList();

    await transaction(() async {
      await eraseAllUserData();
      Future<void> insertAll<T extends Insertable<T>>(
        TableInfo<Table, T> table,
        Iterable<T> values,
      ) async {
        for (final value in values) {
          await into(table).insert(value, mode: InsertMode.insertOrReplace);
        }
      }

      await insertAll(activities, restoredActivities);
      await insertAll(activitySamples, restoredSamples);
      await insertAll(athleteSettings, restoredSettings);
      await insertAll(dailyRecoveryRecords, restoredRecovery);
      await insertAll(bodyMeasurements, restoredBody);
      await insertAll(plannedSessions, restoredPlans);
      await insertAll(ftpEstimates, restoredFtp);
      await insertAll(trainingPreferences, restoredPreferences);
      await insertAll(eventGoals, restoredEvents);
      await insertAll(nutritionEntries, restoredNutrition);
      await insertAll(dailyNutritionTargets, restoredTargets);
      await insertAll(postRideFeedbacks, restoredFeedback);
      await insertAll(rideCoachReports, restoredRideReports);
      await insertAll(savedFoods, restoredFoods);
      await insertAll(strengthProfiles, restoredProfiles);
      await insertAll(strengthSessions, restoredStrengthSessions);
      await insertAll(strengthSets, restoredStrengthSets);
      await insertAll(coachingDecisions, restoredDecisions);
      await insertAll(workoutResponseProfiles, restoredResponses);
    });
  }

  Future<void> eraseAllUserData() => transaction(() async {
        await delete(rideCoachReports).go();
        await delete(coachingDecisions).go();
        await delete(workoutResponseProfiles).go();
        await delete(postRideFeedbacks).go();
        await delete(activitySamples).go();
        await delete(activities).go();
        await delete(dailyRecoveryRecords).go();
        await delete(bodyMeasurements).go();
        await delete(plannedSessions).go();
        await delete(ftpEstimates).go();
        await delete(trainingPreferences).go();
        await delete(eventGoals).go();
        await delete(athleteSettings).go();
        await delete(nutritionEntries).go();
        await delete(dailyNutritionTargets).go();
        await delete(savedFoods).go();
        await delete(strengthSets).go();
        await delete(strengthSessions).go();
        await delete(strengthProfiles).go();
      });

  Stream<List<NutritionEntry>> watchNutritionEntries(DateTime value) {
    final start = DateTime(value.year, value.month, value.day);
    final end = start.add(const Duration(days: 1));
    return (select(nutritionEntries)
          ..where((row) =>
              row.recordedAt.isBiggerOrEqualValue(start) &
              row.recordedAt.isSmallerThanValue(end))
          ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]))
        .watch();
  }

  Future<List<NutritionEntry>> getNutritionEntries(DateTime value) {
    final start = DateTime(value.year, value.month, value.day);
    final end = start.add(const Duration(days: 1));
    return (select(nutritionEntries)
          ..where((row) =>
              row.recordedAt.isBiggerOrEqualValue(start) &
              row.recordedAt.isSmallerThanValue(end))
          ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]))
        .get();
  }

  Future<List<NutritionEntry>> getRecentNutritionEntries({int limit = 50}) =>
      (select(nutritionEntries)
            ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)])
            ..limit(limit))
          .get();

  Future<List<NutritionEntry>> getNutritionEntriesBetween(
    DateTime start,
    DateTime end,
  ) =>
      (select(nutritionEntries)
            ..where(
              (row) =>
                  row.recordedAt.isBiggerOrEqualValue(start) &
                  row.recordedAt.isSmallerThanValue(end),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.recordedAt)]))
          .get();

  Future<int> saveNutritionEntry(NutritionEntriesCompanion value) =>
      into(nutritionEntries).insert(value);

  Future<void> updateNutritionEntry(
    int id,
    NutritionEntriesCompanion value,
  ) =>
      (update(nutritionEntries)..where((row) => row.id.equals(id)))
          .write(value);

  Future<void> deleteNutritionEntry(int id) =>
      (delete(nutritionEntries)..where((row) => row.id.equals(id))).go();

  Stream<DailyNutritionTarget?> watchNutritionTarget(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (select(dailyNutritionTargets)..where((row) => row.day.equals(day)))
        .watchSingleOrNull();
  }

  Future<DailyNutritionTarget?> getNutritionTarget(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return (select(dailyNutritionTargets)..where((row) => row.day.equals(day)))
        .getSingleOrNull();
  }

  Future<void> saveNutritionTarget(DailyNutritionTargetsCompanion value) =>
      into(dailyNutritionTargets).insertOnConflictUpdate(value);

  Stream<PostRideFeedback?> watchPostRideFeedback(String activityId) =>
      (select(postRideFeedbacks)
            ..where((row) => row.activityId.equals(activityId)))
          .watchSingleOrNull();

  Future<PostRideFeedback?> getPostRideFeedback(String activityId) =>
      (select(postRideFeedbacks)
            ..where((row) => row.activityId.equals(activityId)))
          .getSingleOrNull();

  Future<void> savePostRideFeedback(PostRideFeedbacksCompanion value) =>
      into(postRideFeedbacks).insertOnConflictUpdate(value);

  Stream<List<SavedFood>> watchSavedFoods() =>
      (select(savedFoods)..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch();

  Future<List<SavedFood>> getSavedFoods() =>
      (select(savedFoods)..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .get();

  Future<void> saveFood(SavedFoodsCompanion value) =>
      into(savedFoods).insertOnConflictUpdate(value);

  Future<void> deleteSavedFood(String name) =>
      (delete(savedFoods)..where((row) => row.name.equals(name))).go();

  Stream<StrengthProfile?> watchStrengthProfile() =>
      (select(strengthProfiles)..where((row) => row.id.equals(1)))
          .watchSingleOrNull();

  Future<void> saveStrengthProfile(StrengthProfilesCompanion value) =>
      into(strengthProfiles).insertOnConflictUpdate(value);

  Stream<List<StrengthSession>> watchStrengthSessions() =>
      (select(strengthSessions)
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .watch();

  Future<int> createStrengthSession(StrengthSessionsCompanion value) =>
      into(strengthSessions).insert(value);

  Future<void> completeStrengthSession(int id) =>
      (update(strengthSessions)..where((row) => row.id.equals(id))).write(
        StrengthSessionsCompanion(completedAt: Value(DateTime.now())),
      );

  Future<void> deleteStrengthSession(int id) => transaction(() async {
        await (delete(strengthSets)..where((row) => row.sessionId.equals(id)))
            .go();
        await (delete(strengthSessions)..where((row) => row.id.equals(id)))
            .go();
      });

  Stream<List<StrengthSet>> watchStrengthSets(int sessionId) =>
      (select(strengthSets)
            ..where((row) => row.sessionId.equals(sessionId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.exerciseId),
              (row) => OrderingTerm.asc(row.setNumber),
            ]))
          .watch();

  Future<List<StrengthSet>> getStrengthSets(int sessionId) =>
      (select(strengthSets)..where((row) => row.sessionId.equals(sessionId)))
          .get();

  Future<void> saveStrengthSet(StrengthSetsCompanion value) =>
      into(strengthSets).insertOnConflictUpdate(value);

  static QueryExecutor _openConnection() => driftDatabase(name: 'cycle_ready');
}
