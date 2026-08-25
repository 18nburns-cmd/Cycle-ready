import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/coaching/application/athlete_learning_service.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_activity_matcher.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final planCompletionAdapterProvider = Provider(PlanCompletionAdapter.new);

class PlanCompletionAdapter {
  const PlanCompletionAdapter(this.ref);
  final Ref ref;

  Future<bool> adaptFromYesterday() async {
    final database = ref.read(databaseProvider);
    final sessions = ref.read(plannedSessionRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final planned = await sessions.getRange(yesterday, yesterday);
    if (planned.isEmpty || planned.single.origin != 'adaptive') return false;
    final rides =
        ref.read(activitiesProvider).valueOrNull ?? const <Activity>[];
    final nearby = rides.where((ride) =>
        ride.startedAt.isAfter(yesterday.subtract(const Duration(days: 1))) &&
        ride.startedAt.isBefore(today.add(const Duration(days: 1))));
    final matches = nearby
        .map((ride) => matchPlannedActivity(
              planned: [_plannedCandidate(planned.single)],
              ride: _rideCandidate(ride),
            ))
        .whereType<PlannedActivityMatch>()
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final completed = matches.firstOrNull?.ride;
    final outcome = assessWorkoutCompliance(
      plannedLoad: planned.single.targetLoad,
      plannedMinutes: planned.single.durationMinutes,
      actualLoad: completed?.trainingLoad ?? 0,
      actualMinutes: completed?.durationMinutes ?? 0,
    );
    final feedback = completed == null
        ? null
        : await database.getPostRideFeedback(completed.id);
    await ref.read(athleteLearningServiceProvider).learnFromCompletedSession(
          day: yesterday,
          workoutType: planned.single.sessionType,
          compliance: outcome,
          perceivedEffort: feedback?.perceivedEffort,
          legFatigue: feedback?.legFatigue,
        );
    if (outcome.outcome != PlannedWorkoutOutcome.overTarget) return false;

    final upcoming =
        await sessions.getRange(today, today.add(const Duration(days: 3)));
    final next = upcoming
        .where((session) =>
            session.origin == 'adaptive' &&
            session.sessionType != SessionType.rest.name)
        .firstOrNull;
    if (next == null ||
        next.adaptationReason.contains('actual load exceeded the plan')) {
      return false;
    }
    final athlete = await database.getAthleteSettings();
    await sessions.save(PlannedSessionWrite(
      day: next.day,
      sessionType: SessionType.recovery.name,
      title: 'Recovery spin · adjusted after completed load',
      durationMinutes: 35,
      targetLoad: 15,
      confirmed: next.confirmed,
      prescription:
          'Below ${(athlete.ftp * .55).round()} W · keep this genuinely easy',
      origin: 'adaptive',
      adaptationReason:
          'Your actual load yesterday exceeded the plan by ${((outcome.loadRatio - 1) * 100).round()}%. '
          'The next cycling session has been reduced so that you absorb that extra work rather than stacking another demanding stimulus before recovery catches up.',
    ));
    return true;
  }

  PlannedMatchCandidate _plannedCandidate(PlannedSession value) =>
      PlannedMatchCandidate(
        id: value.day.toIso8601String(),
        day: value.day,
        sessionType: value.sessionType,
        title: value.title,
        durationMinutes: value.durationMinutes,
        targetLoad: value.targetLoad,
      );

  CompletedRideCandidate _rideCandidate(Activity value) =>
      CompletedRideCandidate(
        id: value.id,
        startedAt: value.startedAt,
        title: value.title,
        durationMinutes: value.durationSeconds ~/ 60,
        trainingLoad: value.trainingLoad,
      );
}
