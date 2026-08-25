import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persistence input owned by coaching rather than by Drift.
class PlannedSessionWrite {
  const PlannedSessionWrite({
    required this.day,
    required this.sessionType,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    this.confirmed = true,
    this.prescription = '',
    this.origin = 'manual',
    this.adaptationReason = '',
  });

  final DateTime day;
  final String sessionType;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final bool confirmed;
  final String prescription;
  final String origin;
  final String adaptationReason;

  factory PlannedSessionWrite.fromStored(PlannedSession value,
          {String? title}) =>
      PlannedSessionWrite(
        day: value.day,
        sessionType: value.sessionType,
        title: title ?? value.title,
        durationMinutes: value.durationMinutes,
        targetLoad: value.targetLoad,
        confirmed: value.confirmed,
        prescription: value.prescription,
        origin: value.origin,
        adaptationReason: value.adaptationReason,
      );
}

class TrainingPreferencesWrite {
  const TrainingPreferencesWrite({
    required this.goal,
    required this.daysPerWeek,
    required this.longRideWeekday,
    required this.availabilityJson,
  });

  final String goal;
  final int daysPerWeek;
  final int longRideWeekday;
  final String availabilityJson;

  factory TrainingPreferencesWrite.fromStored(TrainingPreference value) =>
      TrainingPreferencesWrite(
        goal: value.goal,
        daysPerWeek: value.daysPerWeek,
        longRideWeekday: value.longRideWeekday,
        availabilityJson: value.availabilityJson,
      );
}

abstract interface class PlannedSessionRepository {
  Stream<PlannedSession?> watchDay(DateTime day);
  Stream<List<PlannedSession>> watchRange(DateTime start, DateTime end);
  Stream<TrainingPreference?> watchPreferences();
  Future<List<PlannedSession>> getRange(DateTime start, DateTime end);
  Future<TrainingPreference> getPreferences();
  Future<void> save(PlannedSessionWrite value);
  Future<void> savePreferences(TrainingPreferencesWrite value);
  Future<void> deleteDay(DateTime day);
  Future<void> deleteAdaptive(DateTime start, DateTime end);
}

class DriftPlannedSessionRepository implements PlannedSessionRepository {
  DriftPlannedSessionRepository(this.database);

  final AppDatabase database;

  @override
  Stream<PlannedSession?> watchDay(DateTime day) =>
      database.watchPlannedSession(day);

  @override
  Stream<List<PlannedSession>> watchRange(DateTime start, DateTime end) =>
      database.watchPlannedSessions(start, end);

  @override
  Stream<TrainingPreference?> watchPreferences() =>
      database.watchTrainingPreferences();

  @override
  Future<List<PlannedSession>> getRange(DateTime start, DateTime end) =>
      database.getPlannedSessions(start, end);

  @override
  Future<TrainingPreference> getPreferences() =>
      database.getTrainingPreferences();

  @override
  Future<void> save(PlannedSessionWrite value) =>
      database.savePlannedSession(PlannedSessionsCompanion.insert(
        day: DateTime(value.day.year, value.day.month, value.day.day),
        sessionType: value.sessionType,
        title: value.title,
        durationMinutes: value.durationMinutes,
        targetLoad: value.targetLoad,
        confirmed: Value(value.confirmed),
        prescription: Value(value.prescription),
        origin: Value(value.origin),
        adaptationReason: Value(value.adaptationReason),
      ));

  @override
  Future<void> savePreferences(TrainingPreferencesWrite value) =>
      database.saveTrainingPreferences(TrainingPreferencesCompanion.insert(
        id: const Value(1),
        goal: Value(value.goal),
        daysPerWeek: Value(value.daysPerWeek),
        longRideWeekday: Value(value.longRideWeekday),
        availabilityJson: Value(value.availabilityJson),
      ));

  @override
  Future<void> deleteDay(DateTime day) => database.deletePlannedSession(day);

  @override
  Future<void> deleteAdaptive(DateTime start, DateTime end) =>
      database.deleteAdaptivePlannedSessions(start, end);
}

final plannedSessionRepositoryProvider = Provider<PlannedSessionRepository>(
  (ref) => DriftPlannedSessionRepository(ref.watch(databaseProvider)),
);
