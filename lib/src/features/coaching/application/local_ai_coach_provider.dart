import 'dart:async';

import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/activities/application/ftp_estimate_controller.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/body/application/body_measurement_controller.dart';
import 'package:cycle_ready/src/features/body/domain/body_metric.dart';
import 'package:cycle_ready/src/features/coaching/application/local_ai_coach_service.dart';
import 'package:cycle_ready/src/features/coaching/application/local_ai_model_manager.dart';
import 'package:cycle_ready/src/features/coaching/domain/ai_readiness_engine.dart';
import 'package:cycle_ready/src/features/coaching/domain/cycling_metrics_engine.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_insight_engine.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_recommendation_engine.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_time.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LocalCoachTask {
  todaysReadiness,
  todaysRecommendation,
  latestRide,
  weeklyReview,
  fitnessTrend,
  recoveryAnalysis,
  askCoach,
}

String localCoachTaskLabel(LocalCoachTask task) => switch (task) {
      LocalCoachTask.todaysReadiness => "Today's Readiness",
      LocalCoachTask.todaysRecommendation => "Today's Recommendation",
      LocalCoachTask.latestRide => 'Analyse My Latest Ride',
      LocalCoachTask.weeklyReview => 'Weekly Training Review',
      LocalCoachTask.fitnessTrend => 'Fitness Trend',
      LocalCoachTask.recoveryAnalysis => 'Recovery Analysis',
      LocalCoachTask.askCoach => 'Ask My Coach',
    };

class LocalCoachDataset {
  const LocalCoachDataset({
    required this.metrics,
    required this.readiness,
    required this.insights,
    required this.recommendation,
    required this.recoveryHours,
    this.performanceMomentum,
  });
  final CyclingMetricsSnapshot metrics;
  final AiReadinessResult readiness;
  final List<String> insights;
  final TrainingRecommendation recommendation;
  final int recoveryHours;
  final PerformanceMomentum? performanceMomentum;

  Map<String, Object?> forTask(LocalCoachTask task) {
    final common = <String, Object?>{
      'readiness': readiness.toJson(),
      'safetyRecommendation': {
        'label': 'RECOMMENDATION',
        'value': recommendation.name.toUpperCase(),
      },
      'recoveryHours': {'label': 'CALCULATED', 'value': recoveryHours},
      'detectedInsights': insights,
      if (performanceMomentum != null)
        'powerMomentum': {
          'label': performanceMomentum!.status.name.toUpperCase(),
          'averageChangePercent': double.parse(
            performanceMomentum!.averageChangePercent.toStringAsFixed(1),
          ),
          'comparisonCount': performanceMomentum!.comparisonCount,
          'interpretation': performanceMomentum!.explanation,
        },
    };
    return switch (task) {
      LocalCoachTask.latestRide => {
          ...common,
          if (metrics.latestRide != null) 'latestRide': metrics.latestRide,
        },
      LocalCoachTask.todaysReadiness ||
      LocalCoachTask.todaysRecommendation ||
      LocalCoachTask.recoveryAnalysis =>
        {
          ...common,
          'metrics': metrics.toJson()['metrics'],
        },
      LocalCoachTask.weeklyReview ||
      LocalCoachTask.fitnessTrend ||
      LocalCoachTask.askCoach =>
        {
          ...common,
          ...metrics.toJson(),
        },
    };
  }
}

final localAiCoachServiceProvider = Provider<LocalAiCoachService>((ref) {
  final service = LocalAiCoachService();
  ref.onDispose(service.dispose);
  return service;
});

final localCoachDatasetProvider = Provider<LocalCoachDataset>((ref) {
  final now = DateTime.now();
  final activities =
      ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
  final athlete = ref.watch(athleteSettingsProvider).valueOrNull;
  final training = ref.watch(fitnessMetricsProvider);
  final existingReadiness = ref.watch(todayReadinessProvider);
  final recovery = ref.watch(recoveryControllerProvider).valueOrNull ??
      RecoveryInput.defaults();
  final body =
      ref.watch(bodyMeasurementsProvider).valueOrNull ?? const <BodyMetric>[];
  final ftpHistory = ref.watch(ftpEstimateHistoryProvider).valueOrNull ??
      const <FtpEstimate>[];
  final strength = ref.watch(strengthWorkloadsProvider).valueOrNull ?? const [];
  final powerProgress =
      ref.watch(powerCurveProgressProvider).valueOrNull ?? const [];
  final sessions = <({DateTime finishedAt, double load})>[
    ...activities.map((activity) => (
          finishedAt: activity.startedAt
              .add(Duration(seconds: activity.durationSeconds)),
          load: activity.trainingLoad?.toDouble() ??
              estimateActivityLoad(
                durationSeconds: activity.durationSeconds,
                normalisedPower: activity.normalisedPower,
                averageHeartRate: activity.averageHeartRate,
                ftp: athlete?.ftp ?? 200,
                restingHeartRate: athlete?.restingHeartRate ?? 50,
                maximumHeartRate: athlete?.maximumHeartRate ?? 190,
              ).value,
        )),
    ...strength.map((item) => (
          finishedAt: item.completedAt,
          load: item.load,
        )),
  ];
  final sleepScore = recovery.sleepTargetMinutes <= 0
      ? null
      : (recovery.sleepMinutes / recovery.sleepTargetMinutes * 100)
          .clamp(0, 100)
          .round();
  final recoveryTime = calculateRecoveryTime(
    sessions: sessions,
    now: now,
    readiness: existingReadiness.score,
    sleepScore: sleepScore ?? 70,
    form: training.form,
    acuteFatigue: training.fatigue,
    perceivedFatigue: recovery.fatigue,
    soreness: recovery.soreness,
  );
  final hard = activities.where((activity) {
    if (activity.startedAt.isBefore(now.subtract(const Duration(days: 7)))) {
      return false;
    }
    return (activity.trainingLoad ?? 0) >= 70 ||
        (activity.normalisedPower != null &&
            athlete != null &&
            activity.normalisedPower! / athlete.ftp >= .9);
  }).length;
  final readiness = const AiReadinessEngine().calculate(
    hrv: recovery.hasHealthData ? recovery.hrvMilliseconds : null,
    hrvBaseline:
        recovery.hasHealthData ? recovery.baselineHrvMilliseconds : null,
    restingHr: recovery.hasHealthData ? recovery.restingHeartRate : null,
    restingHrBaseline:
        recovery.hasHealthData ? recovery.baselineRestingHeartRate : null,
    sleepHours: recovery.hasHealthData ? recovery.sleepMinutes / 60 : null,
    sleepTargetHours:
        recovery.hasHealthData ? recovery.sleepTargetMinutes / 60 : null,
    load7Days: training.weeklyLoad,
    usualLoad7Days: training.fitness * 7,
    hardSessions7Days: hard,
    form: training.form,
    recoveryHours: recoveryTime.remainingHours,
    fatigue: recovery.fatigue,
  );
  final metrics = const CyclingMetricsEngine().calculate(
    activities: activities,
    athlete: athlete,
    training: training,
    recovery: recovery,
    body: body,
    ftpHistory: ftpHistory,
    now: now,
  );
  final load28Average = training.history
          .skip(
              (training.history.length - 28).clamp(0, training.history.length))
          .fold<double>(0, (sum, day) => sum + day.load) /
      4;
  final insights = const TrainingInsightEngine().analyse(
    fitnessRampRate: training.rampRate,
    form: training.form,
    load7Days: training.weeklyLoad,
    load28DayWeeklyAverage: load28Average,
    hardSessions7Days: hard,
    hrv: recovery.hasHealthData ? recovery.hrvMilliseconds : null,
    hrvBaseline:
        recovery.hasHealthData ? recovery.baselineHrvMilliseconds : null,
    restingHr: recovery.hasHealthData ? recovery.restingHeartRate : null,
    restingHrBaseline:
        recovery.hasHealthData ? recovery.baselineRestingHeartRate : null,
    sleepHours: recovery.hasHealthData ? recovery.sleepMinutes / 60 : null,
  );
  final recommendation = const TrainingRecommendationEngine().recommend(
    readiness: readiness.score,
    form: training.form,
    hardSessions7Days: hard,
    recoveryHours: recoveryTime.remainingHours,
  );
  return LocalCoachDataset(
    metrics: metrics,
    readiness: readiness,
    insights: insights,
    recommendation: recommendation,
    recoveryHours: recoveryTime.remainingHours,
    performanceMomentum: assessPerformanceMomentum(powerProgress),
  );
});

class LocalAiCoachState {
  const LocalAiCoachState({
    this.task = LocalCoachTask.todaysRecommendation,
    this.generating = false,
    this.streamedText = '',
    this.response,
    this.error,
  });
  final LocalCoachTask task;
  final bool generating;
  final String streamedText;
  final LocalCoachResponse? response;
  final String? error;
}

final localAiCoachControllerProvider =
    StateNotifierProvider<LocalAiCoachController, LocalAiCoachState>(
  LocalAiCoachController.new,
);

class LocalAiCoachController extends StateNotifier<LocalAiCoachState> {
  LocalAiCoachController(this.ref) : super(const LocalAiCoachState());
  final Ref ref;
  StreamSubscription<String>? _subscription;

  void selectTask(LocalCoachTask task) => state = LocalAiCoachState(task: task);

  Future<void> generate({String? question}) async {
    final model = ref.read(localAiModelManagerProvider);
    if (!model.installed || model.path == null) {
      state = LocalAiCoachState(
        task: state.task,
        error: 'Download the local model before using AI Coach.',
      );
      return;
    }
    final task = state.task;
    state = LocalAiCoachState(task: task, generating: true);
    final buffer = StringBuffer();
    try {
      final stream = ref.read(localAiCoachServiceProvider).generate(
            modelPath: model.path!,
            task: localCoachTaskLabel(task),
            data: ref.read(localCoachDatasetProvider).forTask(task),
            question: question,
          );
      final completer = Completer<void>();
      _subscription = stream.listen(
        (token) {
          buffer.write(token);
          state = LocalAiCoachState(
            task: task,
            generating: true,
            streamedText: buffer.toString(),
          );
        },
        onError: (Object error) {
          state = LocalAiCoachState(task: task, error: error.toString());
          completer.complete();
        },
        onDone: () {
          final text = buffer.toString();
          state = LocalAiCoachState(
            task: task,
            streamedText: text,
            response: LocalCoachResponse.parse(text),
          );
          completer.complete();
        },
      );
      await completer.future;
    } catch (error) {
      state = LocalAiCoachState(task: task, error: error.toString());
    }
  }

  Future<void> cancel() async {
    await ref.read(localAiCoachServiceProvider).cancel();
    await _subscription?.cancel();
    state = LocalAiCoachState(
      task: state.task,
      streamedText: state.streamedText,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
