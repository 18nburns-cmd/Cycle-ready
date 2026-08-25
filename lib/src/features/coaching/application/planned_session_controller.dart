import 'dart:convert';

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:cycle_ready/src/features/intervals/data/intervals_workout_delivery.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_delivery.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/data/drift_event_goal_repository.dart';
import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/weather/data/cached_weather_repository.dart';
import 'package:cycle_ready/src/features/weather/domain/weather_workout_adjustment.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';

final todayPlannedSessionProvider = StreamProvider<PlannedSession?>(
  (ref) => ref.watch(plannedSessionRepositoryProvider).watchDay(DateTime.now()),
);

final plannedSessionControllerProvider = Provider(PlannedSessionController.new);
final workoutDeliveryProvider = Provider<WorkoutDeliveryProvider>((ref) =>
    IntervalsWorkoutDeliveryProvider(ref.watch(intervalsIcuServiceProvider)));
final trainingPreferencesProvider = StreamProvider<TrainingPreference?>(
  (ref) => ref.watch(plannedSessionRepositoryProvider).watchPreferences(),
);

typedef CalendarRange = ({DateTime start, DateTime end});

final plannedSessionsProvider =
    StreamProvider.family<List<PlannedSession>, CalendarRange>(
  (ref, range) => ref
      .watch(plannedSessionRepositoryProvider)
      .watchRange(range.start, range.end),
);

class PlannedSessionController {
  PlannedSessionController(this.ref);
  final Ref ref;

  PlannedSessionRepository get _sessions =>
      ref.read(plannedSessionRepositoryProvider);

  Future<void> confirm(DailySession session) async {
    final date = session.date;
    final rides =
        ref.read(activitiesProvider).valueOrNull ?? const <Activity>[];
    final alreadyCompleted = rides.any((ride) =>
        ride.startedAt.year == date.year &&
        ride.startedAt.month == date.month &&
        ride.startedAt.day == date.day);
    if (alreadyCompleted) return;
    await _sessions.save(
      PlannedSessionWrite(
        day: DateTime(date.year, date.month, date.day),
        sessionType: session.type.name,
        title: session.title,
        durationMinutes: session.durationMinutes,
        targetLoad: session.targetLoad,
        confirmed: true,
      ),
    );
  }

  Future<void> confirmAll(Iterable<DailySession> sessions) async {
    for (final session in sessions) {
      await confirm(session);
    }
  }

  Future<void> save({
    required DateTime day,
    required SessionType type,
    required int durationMinutes,
    required int targetLoad,
  }) {
    final title = switch (type) {
      SessionType.rest => 'Rest day',
      SessionType.recovery => 'Recovery · $durationMinutes min',
      SessionType.endurance => 'Endurance · $durationMinutes min',
      SessionType.tempo => 'Tempo · $durationMinutes min',
      SessionType.intervals => 'Intervals · $durationMinutes min',
    };
    final settings = ref.read(athleteSettingsProvider).valueOrNull;
    final ftp = settings?.ftp ?? 200;
    final prescription = switch (type) {
      SessionType.rest => 'No riding planned.',
      SessionType.recovery => 'Below ${(ftp * .55).round()} W · easy spin',
      SessionType.endurance =>
        '${(ftp * .60).round()}–${(ftp * .72).round()} W · Zone 2',
      SessionType.tempo =>
        '${(ftp * .80).round()}–${(ftp * .90).round()} W · controlled tempo',
      SessionType.intervals =>
        '${(ftp * .95).round()}–${(ftp * 1.05).round()} W · interval efforts',
    };
    return _sessions.save(
      PlannedSessionWrite(
        day: DateTime(day.year, day.month, day.day),
        sessionType: type.name,
        title: title,
        durationMinutes: durationMinutes,
        targetLoad: targetLoad,
        confirmed: true,
        prescription: prescription,
        origin: 'manual',
      ),
    );
  }

  Future<void> savePreferences({
    required TrainingGoal goal,
    required int daysPerWeek,
    required int longRideWeekday,
  }) async {
    final current = await _sessions.getPreferences();
    await _sessions.savePreferences(
      TrainingPreferencesWrite(
        goal: goal.name,
        daysPerWeek: daysPerWeek,
        longRideWeekday: longRideWeekday,
        availabilityJson: current.availabilityJson,
      ),
    );
  }

  Future<List<CyclingAvailability>> getAvailability() async {
    final preferences = await _sessions.getPreferences();
    if (preferences.availabilityJson.isEmpty) {
      return defaultCyclingAvailability();
    }
    try {
      final decoded = jsonDecode(preferences.availabilityJson) as List;
      return decoded
          .map((value) => CyclingAvailability.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
    } catch (_) {
      return defaultCyclingAvailability();
    }
  }

  Future<void> saveAvailability(List<CyclingAvailability> availability) async {
    final current = await _sessions.getPreferences();
    await _sessions.savePreferences(
      TrainingPreferencesWrite(
        goal: current.goal,
        daysPerWeek: availability.where((value) => value.enabled).length,
        longRideWeekday: current.longRideWeekday,
        availabilityJson: jsonEncode(
          availability.map((value) => value.toJson()).toList(),
        ),
      ),
    );
  }

  Future<int> generateAdaptivePlan() async {
    final database = ref.read(databaseProvider);
    final preferences = await _sessions.getPreferences();
    final availability = await getAvailability();
    final athlete = await ref.read(athleteProfileProvider.future);
    final effectiveAvailability = applyEquipmentConstraints(
      availability,
      hasIndoorTrainer: athlete.hasIndoorTrainer,
    );
    final event = await ref.read(eventGoalRepositoryProvider).getGoal();
    final rides =
        ref.read(activitiesProvider).valueOrNull ?? const <Activity>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.add(const Duration(days: 1));
    final metrics = ref.read(fitnessMetricsProvider);
    final strength = await ref.read(strengthWorkloadsProvider.future);
    final previousPlan = await _sessions.getRange(
      today.subtract(const Duration(days: 7)),
      today.subtract(const Duration(days: 1)),
    );
    final missedSessions = previousPlan.where((session) {
      if (session.sessionType == SessionType.rest.name) return false;
      final completedRide =
          rides.any((ride) => _sameDay(ride.startedAt, session.day));
      final completedStrength =
          strength.any((workout) => _sameDay(workout.startedAt, session.day));
      return !completedRide && !completedStrength;
    }).length;
    final demandingToday = rides.any(
          (ride) =>
              _sameDay(ride.startedAt, today) && (ride.trainingLoad ?? 0) >= 60,
        ) ||
        strength.any(
          (workout) => _sameDay(workout.startedAt, today) && workout.load >= 35,
        );
    final avoidHardDays = <DateTime>{if (demandingToday) start};
    final recoveryDays = <DateTime>{};
    for (final ride in rides.where(
      (ride) => ride.startedAt.isAfter(today.subtract(const Duration(days: 3))),
    )) {
      final feedback = await database.getPostRideFeedback(ride.id);
      if (feedback == null) continue;
      final adjustment = trainingAdjustmentFromFeedback(
        PostRideFeedbackInput(
          perceivedEffort: feedback.perceivedEffort,
          legFatigue: feedback.legFatigue,
          enjoyment: feedback.enjoyment,
          discomfort: feedback.discomfort,
        ),
      );
      final nextDay = DateTime(
        ride.startedAt.year,
        ride.startedAt.month,
        ride.startedAt.day,
      ).add(const Duration(days: 1));
      if (!nextDay.isBefore(start)) {
        if (adjustment == PostRideTrainingAdjustment.recoveryOnly) {
          recoveryDays.add(nextDay);
        } else if (adjustment == PostRideTrainingAdjustment.avoidIntensity) {
          avoidHardDays.add(nextDay);
        }
      }
    }
    var plan = const AdaptivePlanGenerator().generate(
      start: start,
      goal: TrainingGoal.values.firstWhere(
        (value) => value.name == preferences.goal,
        orElse: () => TrainingGoal.generalFitness,
      ),
      daysPerWeek: preferences.daysPerWeek,
      longRideWeekday: preferences.longRideWeekday,
      ftp: athlete.ftp,
      currentWeeklyLoad: metrics.weeklyLoad,
      readiness: ref.read(todayReadinessProvider).score,
      form: metrics.form,
      rampRate: metrics.rampRate,
      missedSessions: missedSessions,
      avoidHardDays: avoidHardDays,
      recoveryDays: recoveryDays,
      eventDate: event?.eventDate,
      eventLongRideMinutes: event?.longRideMinutes,
      availability: effectiveAvailability,
    );
    if (athlete.trainingLocation.isNotEmpty) {
      try {
        final forecast = await ref.read(weatherRepositoryProvider).forecast(
              location: athlete.trainingLocation,
              rideTimeMinutes: athlete.preferredRideTimeMinutes,
            );
        plan = plan
            .map((workout) => applyWeatherToWorkout(
                  workout,
                  weather: forecast.isStaleAt(DateTime.now())
                      ? null
                      : forecast.values[DateTime(
                          workout.day.year,
                          workout.day.month,
                          workout.day.day,
                        )],
                  hasIndoorTrainer: athlete.hasIndoorTrainer,
                  safetyProfile: RidingSafetyProfile.values.firstWhere(
                    (value) => value.name == athlete.ridingSafetyProfile,
                    orElse: () => RidingSafetyProfile.balanced,
                  ),
                ))
            .toList();
      } catch (_) {
        // A forecast outage must never prevent the offline-first plan building.
      }
    }
    final planEnd = start.add(const Duration(days: 28));
    final existingFuture = await _sessions.getRange(start, planEnd);
    final protectedDays = existingFuture
        .where((session) => session.origin != 'adaptive')
        .map((session) => DateTime(
              session.day.year,
              session.day.month,
              session.day.day,
            ))
        .toSet();
    await _sessions.deleteAdaptive(start, planEnd);
    var saved = 0;
    for (final workout in plan) {
      final completed = rides.any((ride) =>
          ride.startedAt.year == workout.day.year &&
          ride.startedAt.month == workout.day.month &&
          ride.startedAt.day == workout.day.day);
      if (completed) continue;
      if (protectedDays.any((day) => _sameDay(day, workout.day))) continue;
      await _sessions.save(
        PlannedSessionWrite(
          day: workout.day,
          sessionType: workout.type.name,
          title: workout.title,
          durationMinutes: workout.durationMinutes,
          targetLoad: workout.targetLoad,
          confirmed: true,
          prescription: workout.prescription,
          origin: 'adaptive',
          adaptationReason:
              'Scheduled for ${(workout.startMinutes ~/ 60).toString().padLeft(2, '0')}:'
              '${(workout.startMinutes % 60).toString().padLeft(2, '0')}. '
              '${workout.reason}',
        ),
      );
      await database.saveCoachingDecision(
        CoachingDecisionsCompanion.insert(
          createdAt: DateTime.now(),
          scheduledDay: workout.day,
          workoutType: workout.type.name,
          title: workout.title,
          reason: workout.reason,
          readiness: ref.read(todayReadinessProvider).score,
          fitness: metrics.fitness,
          fatigue: metrics.fatigue,
          form: metrics.form,
          targetLoad: workout.targetLoad,
          confidence: Value(
            (.55 +
                    (rides.length.clamp(0, 20) / 100) +
                    (metrics.history.isEmpty ? 0 : .1))
                .clamp(.55, .9),
          ),
        ),
      );
      saved++;
    }
    return saved;
  }

  Future<bool> maintainRollingPlan() async {
    final preferences = await _sessions.getPreferences();
    if (preferences.availabilityJson.isEmpty) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final future = await _sessions.getRange(
      today,
      today.add(const Duration(days: 35)),
    );
    final adaptive = future
        .where((session) => session.origin == 'adaptive')
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    var renamed = false;
    for (final session in adaptive) {
      final title = _adaptiveDisplayTitle(session);
      if (title == session.title) continue;
      await _sessions
          .save(PlannedSessionWrite.fromStored(session, title: title));
      renamed = true;
    }
    final coverageEnd = adaptive.isEmpty ? null : adaptive.last.day;
    if (coverageEnd != null &&
        !coverageEnd.isBefore(today.add(const Duration(days: 10)))) {
      return renamed;
    }
    await generateAdaptivePlan();
    return true;
  }

  /// Rebuilds FTP-dependent targets only when an adaptive future plan already
  /// exists. Manual sessions and completed history are never selected for
  /// deletion by [generateAdaptivePlan].
  Future<bool> refreshAdaptivePlanForFtpChange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final future = await _sessions.getRange(
      today,
      today.add(const Duration(days: 35)),
    );
    if (!future.any((session) => session.origin == 'adaptive')) return false;
    await generateAdaptivePlan();
    return true;
  }

  String _adaptiveDisplayTitle(PlannedSession session) {
    final interval = RegExp(r'(\d+)\D+(\d+)\s*min', caseSensitive: false)
        .firstMatch(session.title);
    final structure = interval == null
        ? null
        : '${interval.group(1)} × ${interval.group(2)} min';
    final lower = session.title.toLowerCase();
    final base = switch (session.sessionType) {
      'rest' => 'Rest day',
      'recovery' => 'Recovery',
      'endurance' when lower.contains('taper') => 'Taper endurance',
      'endurance' when lower.contains('event') => 'Event endurance',
      'endurance' => 'Endurance',
      'tempo' when lower.contains('sweet') => 'Sweet spot',
      'tempo' => 'Tempo',
      'intervals' when lower.contains('vo2') => 'VO2 max',
      'intervals' => 'Threshold',
      _ => 'Cycling',
    };
    if (session.sessionType == 'rest') return base;
    return structure == null
        ? '$base · ${session.durationMinutes} min'
        : '$base · $structure';
  }

  Future<int> publishUpcomingToIntervals() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 14));
    final sessions = await _sessions.getRange(start, end);
    final rides =
        ref.read(activitiesProvider).valueOrNull ?? const <Activity>[];
    final workouts = sessions
        .where((session) =>
            session.sessionType != SessionType.rest.name &&
            session.durationMinutes > 0 &&
            !rides.any((ride) =>
                ride.startedAt.year == session.day.year &&
                ride.startedAt.month == session.day.month &&
                ride.startedAt.day == session.day.day))
        .map((session) => buildStructuredWorkout(
              id: 'cycleready-${session.day.year}-${session.day.month.toString().padLeft(2, '0')}-${session.day.day.toString().padLeft(2, '0')}',
              day: session.day,
              sessionType: session.sessionType,
              title: session.title,
              requestedMinutes: session.durationMinutes,
              targetLoad: session.targetLoad,
            ))
        .toList();
    final result = await ref.read(workoutDeliveryProvider).deliver(workouts);
    return result.delivered;
  }

  Future<void> delete(DateTime day) => _sessions.deleteDay(day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
