import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/activities/domain/training_response.dart';
import 'package:cycle_ready/src/features/coaching/application/coaching_provider.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/presentation/workout_profile_chart.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_time.dart';
import 'package:cycle_ready/src/features/dashboard/domain/personal_greeting.dart';
import 'package:cycle_ready/src/features/weather/application/today_weather_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_training_load.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(todayReadinessProvider);
    final rides =
        ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
    final athlete = ref.watch(athleteSettingsProvider).valueOrNull;
    final strength =
        ref.watch(strengthWorkloadsProvider).valueOrNull ?? const [];
    final recovery = ref.watch(recoveryControllerProvider).valueOrNull ??
        RecoveryInput.defaults();
    final training = ref.watch(fitnessMetricsProvider);
    final powerProgress =
        ref.watch(powerCurveProgressProvider).valueOrNull ?? const [];
    final trainingResponse = assessTrainingResponse(
      training: training,
      momentum: assessPerformanceMomentum(powerProgress),
    );
    final coaching = ref.watch(todayCoachingProvider);
    final rideWeather = ref.watch(todayRideWeatherProvider);
    final now = DateTime.now();
    final todayRides = rides
        .where(
          (ride) =>
              ride.startedAt.year == now.year &&
              ride.startedAt.month == now.month &&
              ride.startedAt.day == now.day,
        )
        .toList();
    final todayStrength = strength
        .where((workout) =>
            workout.completedAt.year == now.year &&
            workout.completedAt.month == now.month &&
            workout.completedAt.day == now.day)
        .toList();
    final plannedToday = ref.watch(todayPlannedSessionProvider).valueOrNull;
    final confirmed = plannedToday?.confirmed ?? false;
    final displayedSession = plannedToday == null
        ? coaching.today
        : DailySession(
            date: plannedToday.day,
            type: SessionType.values.firstWhere(
              (value) => value.name == plannedToday.sessionType,
              orElse: () => SessionType.endurance,
            ),
            title: plannedToday.title,
            durationMinutes: plannedToday.durationMinutes,
            targetLoad: plannedToday.targetLoad,
            reason: plannedToday.adaptationReason.isNotEmpty
                ? plannedToday.adaptationReason
                : plannedToday.prescription,
            confidence: coaching.today.confidence,
            evidence: coaching.today.evidence,
          );
    final sleepScore = readiness.factors
        .firstWhere((factor) => factor.label == 'Sleep')
        .score
        .round();
    final completedSessions = <({DateTime finishedAt, double load})>[
      ...rides.map((ride) => (
            finishedAt:
                ride.startedAt.add(Duration(seconds: ride.durationSeconds)),
            load: ride.trainingLoad?.toDouble() ??
                estimateActivityLoad(
                  durationSeconds: ride.durationSeconds,
                  normalisedPower: ride.normalisedPower,
                  averageHeartRate: ride.averageHeartRate,
                  ftp: athlete?.ftp ?? 200,
                  restingHeartRate: athlete?.restingHeartRate ?? 50,
                  maximumHeartRate: athlete?.maximumHeartRate ?? 190,
                ).value,
          )),
      ...strength.map((workout) => (
            finishedAt: workout.completedAt,
            load: workout.load,
          )),
    ];
    final recoveryTime = calculateRecoveryTime(
      sessions: completedSessions,
      now: now,
      readiness: readiness.score,
      sleepScore: sleepScore,
      form: training.form,
      acuteFatigue: training.fatigue,
      perceivedFatigue: recovery.fatigue,
      soreness: recovery.soreness,
    );
    final suggestedWorkout = displayedSession.durationMinutes <= 0
        ? null
        : buildStructuredWorkout(
            id: 'cycleready-today',
            day: now,
            sessionType: displayedSession.type.name,
            title: displayedSession.title,
            requestedMinutes: displayedSession.durationMinutes,
            targetLoad: displayedSession.targetLoad,
            selectionReason: displayedSession.reason,
            confidence: displayedSession.confidence,
          );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(personalGreeting(now),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                tooltip: 'Data and privacy',
                onPressed: () => context.push('/privacy'),
                icon: const Icon(Icons.shield_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${DateTime.now().day}/${DateTime.now().month}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            sliver: SliverList.list(children: [
              Text('TODAY',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              _DailyIndicators(
                sleepScore: sleepScore,
                readiness: readiness.score,
                recoveryTime: recoveryTime,
              ),
              const SizedBox(height: 12),
              Text(
                recoveryTime.remainingHours == 0
                    ? 'Recovery time: you are currently clear of recent training demand.'
                    : '${recoveryTime.displayValue} until another demanding session is advised. ${recoveryTime.explanation}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              _DailyInsight(result: readiness, coaching: coaching),
              if (rideWeather.valueOrNull != null) ...[
                const SizedBox(height: 10),
                _RideWeatherCard(value: rideWeather.valueOrNull!),
              ],
              const SizedBox(height: 10),
              _DashboardTrainingResponse(
                response: trainingResponse,
                onTap: () => context.go('/performance'),
              ),
              const SizedBox(height: 24),
              if (todayRides.isNotEmpty)
                DashboardCompletedRideCard(rides: todayRides)
              else if (todayStrength.isNotEmpty)
                _DashboardCompletedStrengthCard(workouts: todayStrength)
              else
                DashboardWorkoutCard(
                  session: displayedSession,
                  workout: suggestedWorkout,
                  confirmed: confirmed,
                  onConfirm: () => ref
                      .read(plannedSessionControllerProvider)
                      .confirm(displayedSession),
                ),
              const SizedBox(height: 8),
              _TodayLinkCard(
                icon: Icons.restaurant_outlined,
                title: 'Fuel today',
                subtitle:
                    'Track calories, carbohydrate, protein, fat and hydration.',
                onTap: () => context.push('/nutrition'),
              ),
              _TodayLinkCard(
                icon: Icons.fitness_center,
                title: 'Strength training',
                subtitle: 'Your guided gym routine, sets and progress.',
                onTap: () => context.push('/strength'),
              ),
              _TodayLinkCard(
                icon: Icons.auto_awesome,
                title: 'Coach',
                subtitle: 'Your daily analysis, pep talk and recovery actions.',
                onTap: () => context.push('/coach'),
              ),
              _TodayLinkCard(
                icon: Icons.insights,
                title: 'Performance insights',
                subtitle: 'Rolling eight-week trends and personal patterns.',
                onTap: () => context.push('/insights'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

String _shortTime(DateTime value) {
  final now = DateTime.now();
  final sameDay = value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  final minute = value.minute.toString().padLeft(2, '0');
  return sameDay
      ? 'today at ${value.hour}:$minute'
      : '${value.day}/${value.month} at ${value.hour}:$minute';
}

class _RideWeatherCard extends StatelessWidget {
  const _RideWeatherCard({required this.value});

  final TodayRideWeather value;

  @override
  Widget build(BuildContext context) {
    final weather = value.weather;
    final unsafe = value.isUnsafe;
    final color = value.isStale
        ? const Color(0xFFFFB020)
        : unsafe
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF19D879);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .14),
          child: Icon(
            value.isStale
                ? Icons.history
                : unsafe
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_outlined,
            color: color,
          ),
        ),
        title: Text(
          '${weather.temperatureC.round()}°C · ${weather.windGustKph.round()} km/h gusts · ${weather.precipitationProbability}% rain',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          value.isStale
              ? 'Cached forecast from ${_shortTime(value.fetchedAt)}. It is stale, so CycleReady will not use it to change your workout.'
              : unsafe
                  ? 'At your preferred ride time in ${value.location}, ${weather.safetyReason(value.thresholds)}. The planner will protect outdoor sessions.'
                  : 'Conditions at your preferred ride time in ${value.location} are within your ${value.safetyProfile.name} outdoor limits. Updated ${_shortTime(value.fetchedAt)}${value.isCached ? ' from cache' : ''}.',
        ),
        trailing: IconButton(
          tooltip: 'Adjust weather limits',
          onPressed: () => context.push('/athlete'),
          icon: const Icon(Icons.tune),
        ),
      ),
    );
  }
}

class _DashboardTrainingResponse extends StatelessWidget {
  const _DashboardTrainingResponse({
    required this.response,
    required this.onTap,
  });

  final TrainingResponse response;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (response.status) {
      TrainingResponseStatus.productive => (
          Icons.trending_up,
          const Color(0xFF19E56F)
        ),
      TrainingResponseStatus.maintaining => (
          Icons.balance,
          const Color(0xFF4FA9FF)
        ),
      TrainingResponseStatus.fatigued => (
          Icons.battery_alert_outlined,
          const Color(0xFFFFB020)
        ),
      TrainingResponseStatus.rebuilding => (
          Icons.construction,
          const Color(0xFFB58CFF)
        ),
      TrainingResponseStatus.insufficientData => (
          Icons.hourglass_top,
          Theme.of(context).colorScheme.outline
        ),
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING RESPONSE',
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(response.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900, color: color)),
                  Text(
                    _shortResponse(response.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  String _shortResponse(TrainingResponseStatus status) => switch (status) {
        TrainingResponseStatus.productive =>
          'Power is improving while load remains manageable.',
        TrainingResponseStatus.maintaining =>
          'Power and training load are holding steady.',
        TrainingResponseStatus.fatigued =>
          'Recovery should take priority over more hard work.',
        TrainingResponseStatus.rebuilding =>
          'Keep training consistently before reassessing progress.',
        TrainingResponseStatus.insufficientData =>
          'More comparable power efforts are needed.',
      };
}

class _DashboardCompletedStrengthCard extends StatelessWidget {
  const _DashboardCompletedStrengthCard({required this.workouts});

  final List<StrengthWorkoutLoad> workouts;

  @override
  Widget build(BuildContext context) {
    final minutes =
        workouts.fold<int>(0, (sum, workout) => sum + workout.durationMinutes);
    final load = workouts.fold<double>(0, (sum, workout) => sum + workout.load);
    final sets =
        workouts.fold<int>(0, (sum, workout) => sum + workout.completedSets);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Color(0x3319E56F),
          child: Icon(Icons.fitness_center, color: Color(0xFF19E56F)),
        ),
        title: Text(
          workouts.length == 1
              ? 'Strength session completed'
              : '${workouts.length} strength sessions completed',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('$minutes min · $sets sets · ${load.round()} load'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/strength'),
      ),
    );
  }
}

class _TodayLinkCard extends StatelessWidget {
  const _TodayLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _DailyIndicators extends StatelessWidget {
  const _DailyIndicators({
    required this.sleepScore,
    required this.readiness,
    required this.recoveryTime,
  });
  final int sleepScore;
  final int readiness;
  final RecoveryTimeEstimate recoveryTime;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Indicator(
              value: '$sleepScore%',
              progress: sleepScore / 100,
              label: 'SLEEP',
              size: 76,
              color: const Color(0xFF8CB9D0)),
          _Indicator(
              value: '$readiness%',
              progress: readiness / 100,
              label: 'READINESS',
              size: 112,
              color: const Color(0xFF19E56F)),
          _Indicator(
              value: recoveryTime.displayValue,
              progress: recoveryTime.progress,
              label: 'RECOVERY',
              size: 76,
              color: const Color(0xFF16A7E8)),
        ],
      );
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.value,
    required this.progress,
    required this.label,
    required this.color,
    required this.size,
  });
  final String value;
  final double progress;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: size > 90 ? 7 : 5,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white12,
                color: color,
              ),
            ),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
      ]);
}

class _DailyInsight extends StatelessWidget {
  const _DailyInsight({required this.result, required this.coaching});
  final ReadinessResult result;
  final CoachingResult coaching;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(result.headline,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.check_circle,
                  color: result.band == ReadinessBand.low
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF19E56F)),
            ]),
            const SizedBox(height: 8),
            Text(result.recommendation),
            const SizedBox(height: 10),
            Text(coaching.insights.first,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ]),
        ),
      );
}

class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    super.key,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class DashboardWorkoutCard extends StatelessWidget {
  const DashboardWorkoutCard({
    required this.session,
    required this.confirmed,
    required this.onConfirm,
    required this.workout,
    super.key,
  });
  final DailySession session;
  final bool confirmed;
  final VoidCallback onConfirm;
  final StructuredWorkout? workout;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(session.type == SessionType.rest
                    ? Icons.self_improvement
                    : Icons.directions_bike),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(session.durationMinutes == 0
                        ? 'Recovery day'
                        : '${session.durationMinutes} minutes · ${session.targetLoad} planned load'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(workout?.selectionReason ?? session.reason),
            if (session.evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'WHY TODAY',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 5),
              ...session.evidence.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5, right: 8),
                            child: Icon(Icons.circle, size: 6),
                          ),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
            ],
            if (workout != null) ...[
              const SizedBox(height: 12),
              WorkoutProfileChart(workout: workout!, height: 82),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _WorkoutSummaryValue(
                    label: 'CONFIDENCE',
                    value: '${(workout!.confidence * 100).round()}%',
                  ),
                ),
                Expanded(
                  child: _WorkoutSummaryValue(
                    label: 'FATIGUE',
                    value: '${workout!.estimatedFatigue}/100',
                  ),
                ),
                Expanded(
                  child: _WorkoutSummaryValue(
                    label: 'RECOVERY',
                    value: '${workout!.estimatedRecoveryHours}h',
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EXPECTED BENEFIT',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(workout!.expectedAdaptation),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showWorkout(context, workout!),
                icon: const Icon(Icons.format_list_numbered),
                label: const Text('View workout and coach notes'),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: confirmed
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Added to today’s plan'),
                    )
                  : FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.add_task),
                      label: const Text('Use this plan'),
                    ),
            ),
          ]),
        ),
      );

  void _showWorkout(BuildContext context, StructuredWorkout workout) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(workout.description),
                const SizedBox(height: 14),
                WorkoutProfileChart(workout: workout, height: 140),
                const SizedBox(height: 16),
                Text('Coach notes',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(workout.coachNotes),
                const SizedBox(height: 16),
                Text('Workout steps',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final step in workout.steps)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(step.repetitions > 1
                          ? '${step.repetitions}x'
                          : '${workout.steps.indexOf(step) + 1}'),
                    ),
                    title: Text(step.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_stepDescription(step)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepDescription(WorkoutStep step) {
    final duration = step.durationSeconds < 60
        ? '${step.durationSeconds}s'
        : '${step.durationSeconds ~/ 60}m';
    final cadence = step.cadenceLow == null
        ? ''
        : ' · ${step.cadenceLow}-${step.cadenceHigh} rpm';
    final recovery = step.repetitions > 1 && step.recoverySeconds > 0
        ? ' · ${step.recoverySeconds ~/ 60}m recovery'
        : '';
    final heartRate = step.heartRateLowPercent == null
        ? ''
        : ' · HR ${step.heartRateLowPercent}-${step.heartRateHighPercent}% max';
    return '$duration · ${step.powerLowPercent}-${step.powerHighPercent}% FTP · RPE ${step.rpe}$cadence$heartRate$recovery';
  }
}

class _WorkoutSummaryValue extends StatelessWidget {
  const _WorkoutSummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class DashboardCompletedRideCard extends StatelessWidget {
  const DashboardCompletedRideCard({required this.rides, super.key});
  final List<Activity> rides;

  @override
  Widget build(BuildContext context) {
    final latest = rides.reduce(
      (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
    );
    final totalSeconds =
        rides.fold<int>(0, (sum, ride) => sum + ride.durationSeconds);
    final totalDistance =
        rides.fold<double>(0, (sum, ride) => sum + ride.distanceMetres);
    final totalLoad =
        rides.fold<int>(0, (sum, ride) => sum + (ride.trainingLoad ?? 0));
    final duration = '${totalSeconds ~/ 3600}h ${(totalSeconds % 3600) ~/ 60}m';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/activities/${latest.id}/debrief'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFF19D879).withValues(alpha: .16),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF19D879),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rides.length == 1
                              ? latest.title
                              : '${rides.length} rides completed',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Text('Completed today'),
                      ],
                    ),
                  ),
                  const Column(
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(height: 2),
                      Text('DEBRIEF', style: TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RideValue(
                    value: Units.distance(totalDistance),
                    label: 'DISTANCE',
                  ),
                  _RideValue(value: duration, label: 'TIME'),
                  _RideValue(value: '$totalLoad', label: 'LOAD'),
                ],
              ),
              if (rides.length == 1 &&
                  (latest.averagePower != null ||
                      latest.averageHeartRate != null)) ...[
                const Divider(height: 24),
                Text(
                  [
                    if (latest.averagePower != null)
                      '${latest.averagePower} W average power',
                    if (latest.averageHeartRate != null)
                      '${latest.averageHeartRate} bpm average heart rate',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RideValue extends StatelessWidget {
  const _RideValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class RollingHistoryCard extends StatelessWidget {
  const RollingHistoryCard({
    required this.rides,
    required this.history,
    super.key,
  });
  final List<Activity> rides;
  final List<FitnessPoint> history;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final loadByDay = {
      for (final point in history)
        DateTime(point.date.year, point.date.month, point.date.day): point.load,
    };
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: index)),
    );

    return Card(
      child: Column(
        children: days.map((day) {
          final dayRides = rides
              .where((ride) =>
                  ride.startedAt.year == day.year &&
                  ride.startedAt.month == day.month &&
                  ride.startedAt.day == day.day)
              .toList();
          final distance = dayRides.fold<double>(
              0, (sum, ride) => sum + ride.distanceMetres);
          final minutes = dayRides.fold<int>(
              0, (sum, ride) => sum + ride.durationSeconds ~/ 60);
          final load = loadByDay[day] ?? 0;
          final trained = dayRides.isNotEmpty || load > 0;
          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 42,
              child: Text(
                day == today ? 'Today' : _weekday(day),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(trained
                ? dayRides.length == 1
                    ? dayRides.first.title
                    : '${dayRides.length} completed rides'
                : 'Recovery day'),
            subtitle: Text(trained
                ? '${Units.distance(distance)} · $minutes min · load ${load.round()}'
                : 'No completed training'),
            trailing: Icon(
              trained ? Icons.directions_bike_outlined : Icons.self_improvement,
              color: trained
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _weekday(DateTime date) => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][date.weekday - 1];
}

class ReadinessFactorTile extends StatelessWidget {
  const ReadinessFactorTile(this.factor, {super.key});
  final ReadinessFactor factor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(factor.label)),
            Text('${factor.score.round()}'),
          ]),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: factor.score / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(factor.detail,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ]),
      );
}
