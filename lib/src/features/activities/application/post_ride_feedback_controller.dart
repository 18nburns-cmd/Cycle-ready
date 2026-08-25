import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/coach_ai_report.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_debrief.dart';
import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/feedback_plan_adjustment.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_activity_matcher.dart';
import 'package:cycle_ready/src/features/activities/application/workout_execution_adapter.dart';

final postRideFeedbackProvider =
    StreamProvider.family<PostRideFeedback?, String>(
  (ref, activityId) =>
      ref.watch(databaseProvider).watchPostRideFeedback(activityId),
);

final postRideFeedbackControllerProvider =
    Provider(PostRideFeedbackController.new);

final rideCoachReportProvider = StreamProvider.family<RideCoachReport?, String>(
  (ref, activityId) =>
      ref.watch(databaseProvider).watchRideCoachReport(activityId),
);

class PostRideFeedbackController {
  const PostRideFeedbackController(this.ref);
  final Ref ref;

  Future<void> save({
    required String activityId,
    required int perceivedEffort,
    required int legFatigue,
    required int enjoyment,
    required int discomfort,
    required String notes,
  }) async {
    final database = ref.read(databaseProvider);
    await database.savePostRideFeedback(
      PostRideFeedbacksCompanion.insert(
        activityId: activityId,
        perceivedEffort: perceivedEffort,
        legFatigue: legFatigue,
        enjoyment: enjoyment,
        discomfort: discomfort,
        notes: Value(notes.trim()),
        updatedAt: DateTime.now(),
      ),
    );
    final ride = await database.activityById(activityId);
    if (ride == null) return;
    await _persistCoachReport(
      database: database,
      ride: ride,
      perceivedEffort: perceivedEffort,
      legFatigue: legFatigue,
      enjoyment: enjoyment,
      discomfort: discomfort,
    );
    final nextDay = DateTime(
      ride.startedAt.year,
      ride.startedAt.month,
      ride.startedAt.day,
    ).add(const Duration(days: 1));
    final sessions = await database.getPlannedSessions(nextDay, nextDay);
    if (sessions.isEmpty) return;
    final existing = sessions.single;
    final existingType = SessionType.values.firstWhere(
      (value) => value.name == existing.sessionType,
      orElse: () => SessionType.endurance,
    );
    final athlete = await database.getAthleteSettings();
    final planAdjustment = adjustPlanFromFeedback(
      adjustment: trainingAdjustmentFromFeedback(
        PostRideFeedbackInput(
          perceivedEffort: perceivedEffort,
          legFatigue: legFatigue,
          enjoyment: enjoyment,
          discomfort: discomfort,
        ),
      ),
      existingType: existingType,
      ftp: athlete.ftp,
    );
    if (planAdjustment == null) return;
    await database.savePlannedSession(
      PlannedSessionsCompanion.insert(
        day: nextDay,
        sessionType: planAdjustment.type.name,
        title: planAdjustment.title,
        durationMinutes: planAdjustment.durationMinutes,
        targetLoad: planAdjustment.targetLoad,
        confirmed: Value(existing.confirmed),
        prescription: Value(planAdjustment.prescription),
        origin: Value(existing.origin),
        adaptationReason: Value(
          'Adjusted automatically from your post-ride feedback.',
        ),
      ),
    );
  }

  Future<void> _persistCoachReport({
    required AppDatabase database,
    required Activity ride,
    required int perceivedEffort,
    required int legFatigue,
    required int enjoyment,
    required int discomfort,
  }) async {
    final samples = await database.samplesFor(ride.id);
    final athlete = await database.getAthleteSettings();
    final history = await database.getActivities();
    final day = DateTime(
      ride.startedAt.year,
      ride.startedAt.month,
      ride.startedAt.day,
    );
    final candidatePlans = await database.getPlannedSessions(
      day.subtract(const Duration(days: 1)),
      day.add(const Duration(days: 1)),
    );
    final matched = matchPlannedActivity(
      planned: candidatePlans.map(
        (value) => PlannedMatchCandidate(
          id: value.day.toIso8601String(),
          day: value.day,
          sessionType: value.sessionType,
          title: value.title,
          durationMinutes: value.durationMinutes,
          targetLoad: value.targetLoad,
        ),
      ),
      ride: CompletedRideCandidate(
        id: ride.id,
        startedAt: ride.startedAt,
        title: ride.title,
        durationMinutes: ride.durationSeconds ~/ 60,
        trainingLoad: ride.trainingLoad,
      ),
    );
    final planned = candidatePlans
        .where((value) => value.day.toIso8601String() == matched?.planned.id)
        .firstOrNull;
    final advanced = calculateAdvancedRideMetrics(
      durationSeconds: ride.durationSeconds,
      ftp: athlete.ftp,
      samples: samples.map((sample) => (
            elapsedSeconds: sample.elapsedSeconds,
            power: sample.power,
            heartRate: sample.heartRate,
            cadence: sample.cadence,
          )),
    );
    final analysis = analyseRide(
      durationSeconds: ride.durationSeconds,
      distanceMetres: ride.distanceMetres,
      ftp: athlete.ftp,
      maximumHeartRate: athlete.maximumHeartRate,
      weightKg: athlete.weightKg,
      averagePower: ride.averagePower,
      averageHeartRate: ride.averageHeartRate,
      normalisedPower: ride.normalisedPower,
      samples: samples.map((sample) => (
            elapsedSeconds: sample.elapsedSeconds,
            power: sample.power,
            heartRate: sample.heartRate,
          )),
    );
    DebriefRide asDebrief(Activity value) => DebriefRide(
          id: value.id,
          title: value.title,
          startedAt: value.startedAt,
          durationSeconds: value.durationSeconds,
          trainingLoad: value.trainingLoad,
          averagePower: value.averagePower,
          averageHeartRate: value.averageHeartRate,
        );
    final report = buildCoachAiReport(
      ride: asDebrief(ride),
      history: history.map(asDebrief),
      advanced: advanced,
      analysis: analysis,
      ftp: athlete.ftp,
      weightKg: athlete.weightKg,
      plannedType: planned?.sessionType,
      plannedMinutes: planned?.durationMinutes,
      plannedLoad: planned?.targetLoad,
      workoutExecution: planned == null
          ? null
          : buildWorkoutExecutionAnalysis(
              planned: planned,
              ftp: athlete.ftp,
              samples: samples,
            ),
      perceivedEffort: perceivedEffort,
      legFatigue: legFatigue,
      discomfort: discomfort,
      enjoyment: enjoyment,
    );
    await database.saveRideCoachReport(
      RideCoachReportsCompanion.insert(
        activityId: ride.id,
        createdAt: DateTime.now(),
        plannedTitle: Value(planned?.title),
        executionScore: report.executionScore,
        objective: report.objective,
        summary: report.summary,
        execution: report.execution,
        tomorrowRecommendation: report.verdict.tomorrow,
        keyFocus: report.verdict.keyFocus,
        confidence: report.confidence.name,
        confidenceReason: report.confidenceReason,
      ),
    );
  }
}
