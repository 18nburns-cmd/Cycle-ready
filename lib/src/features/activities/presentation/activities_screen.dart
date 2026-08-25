import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cycle_ready/src/features/activities/presentation/fitness_chart.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);
    final metrics = ref.watch(fitnessMetricsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final forecastEnd = DateTime(today.year, today.month, today.day + 14);
    final planned = ref.watch(plannedSessionsProvider((
      start: DateTime(today.year, today.month, today.day + 1),
      end: forecastEnd,
    )));
    ref.listen(activityImportControllerProvider, (_, next) {
      final message = next.valueOrNull;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Cycling'), actions: [
        IconButton(
          tooltip: 'Performance insights',
          onPressed: () => context.push('/insights'),
          icon: const Icon(Icons.insights),
        ),
        IconButton(
          tooltip: 'Sync Intervals.icu',
          onPressed: ref.watch(activityImportControllerProvider).isLoading
              ? null
              : () => ref
                  .read(activityImportControllerProvider.notifier)
                  .syncIntervalsNow(),
          icon: const Icon(Icons.cloud_sync_outlined),
        ),
        IconButton(
          tooltip: 'Calculated FTP',
          onPressed: () => context.push('/ftp-estimate'),
          icon: const Icon(Icons.query_stats),
        ),
        IconButton(
          tooltip: 'Athlete settings',
          onPressed: () => context.push('/athlete'),
          icon: const Icon(Icons.tune),
        ),
      ]),
      body: activities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load rides: $error')),
        data: (_) {
          final sessions = planned.valueOrNull ?? const [];
          return _ActivityList(
            metrics: metrics,
            forecast: projectFitnessForecast(
              history: metrics.history,
              plannedLoads: sessions
                  .where((session) =>
                      session.sessionType != 'rest' && session.targetLoad > 0)
                  .map((session) => (
                        date: session.day,
                        load: session.targetLoad.toDouble(),
                      )),
              through: forecastEnd,
            ),
          );
        },
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.metrics, required this.forecast});
  final TrainingMetrics metrics;
  final List<FitnessPoint> forecast;
  @override
  Widget build(BuildContext context) {
    final ramp = _RampStatus.from(metrics.rampRate);
    final targets = calculateWeeklyLoadTargets(metrics.fitness);
    final outlook = forecast.isEmpty
        ? null
        : summariseFitnessForecast(
            current: metrics.history.last,
            forecast: forecast,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Row(children: [
            Expanded(
                child: _Metric(
                    label: 'Fitness',
                    value: metrics.fitness.toStringAsFixed(0))),
            const SizedBox(width: 8),
            Expanded(
                child: _Metric(
                    label: 'Fatigue',
                    value: metrics.fatigue.toStringAsFixed(0))),
            const SizedBox(width: 8),
            Expanded(
                child: _Metric(
                    label: 'Form', value: metrics.form.toStringAsFixed(0))),
          ]),
          Row(
            children: [
              Expanded(
                child: _CompactStatusCard(
                  icon: Icons.monitor_heart_outlined,
                  value: metrics.weeklyLoad.toStringAsFixed(0),
                  label: '7-day load',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStatusCard(
                  icon: ramp.icon,
                  value: '${metrics.rampRate.toStringAsFixed(1)} / wk',
                  label: ramp.label,
                  color: ramp.color,
                ),
              ),
            ],
          ),
          Expanded(
            child: FitnessChart(
              points: [...metrics.history, ...forecast],
              chartHeight: 245,
              showHelp: false,
            ),
          ),
          _LoadTargetCard(
            current: metrics.weeklyLoad.round(),
            maintain: targets.maintain,
            buildTarget: targets.build,
            outlook: outlook,
            forecast: forecast,
            currentPoint: metrics.history.last,
          ),
          Text(
            ramp.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ramp.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoadTargetCard extends StatelessWidget {
  const _LoadTargetCard({
    required this.current,
    required this.maintain,
    required this.buildTarget,
    required this.outlook,
    required this.forecast,
    required this.currentPoint,
  });

  final int current;
  final int maintain;
  final int buildTarget;
  final FitnessForecastSummary? outlook;
  final List<FitnessPoint> forecast;
  final FitnessPoint currentPoint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: outlook == null
                ? BorderSide.none
                : BorderSide(color: _outlookColor(context, outlook!.status)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: outlook == null ? null : () => _showDetails(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Current $current  ·  Maintain $maintain  ·  Build $buildTarget',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (outlook != null) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.info_outline, size: 15),
                      ],
                    ],
                  ),
                  Text(
                    outlook == null
                        ? 'Add sessions to the calendar to see a 14-day outlook.'
                        : '${outlook!.label}: fitness ${_signed(outlook!.fitnessChange)} '
                            'to ${outlook!.endFitness.toStringAsFixed(1)} · '
                            'form ${outlook!.endForm.toStringAsFixed(1)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: outlook == null
                              ? null
                              : _outlookColor(context, outlook!.status),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  void _showDetails(BuildContext context) {
    final summary = outlook;
    if (summary == null || forecast.isEmpty) return;
    final lowest = forecast.reduce(
      (a, b) => a.form <= b.form ? a : b,
    );
    final plannedLoad = forecast.fold<double>(0, (sum, day) => sum + day.load);
    final safer = buildReducedLoadScenario(
      current: currentPoint,
      forecast: forecast,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your 14-day plan outlook',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 8),
              Text(
                summary.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _outlookColor(context, summary.status),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _OutlookValue(
                        value: _signed(summary.fitnessChange),
                        label: 'Fitness change')),
                Expanded(
                    child: _OutlookValue(
                        value: summary.peakFatigue.toStringAsFixed(1),
                        label: 'Peak fatigue')),
                Expanded(
                    child: _OutlookValue(
                        value: summary.lowestForm.toStringAsFixed(1),
                        label: 'Lowest form')),
                Expanded(
                    child: _OutlookValue(
                        value: plannedLoad.toStringAsFixed(0),
                        label: 'Planned load')),
              ]),
              const SizedBox(height: 18),
              Text(_recommendation(summary.status),
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 10),
              Text(
                'The greatest predicted fatigue occurs around '
                '${lowest.date.day}/${lowest.date.month}. This assumes every '
                'calendar session is completed at its target load; actual rides '
                'will replace the estimate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (safer != null &&
                  (summary.status == ForecastLoadStatus.cautious ||
                      summary.status == ForecastLoadStatus.excessive)) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Safer scenario',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(
                        'Reduce the planned load on ${safer.day.day}/${safer.day.month} '
                        'from ${safer.originalLoad.round()} to '
                        '${safer.reducedLoad.round()} (30% easier).',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Projected fitness ${safer.summary.endFitness.toStringAsFixed(1)} · '
                        'lowest form ${safer.summary.lowestForm.toStringAsFixed(1)} · '
                        '${safer.summary.label}',
                        style: TextStyle(
                          color: _outlookColor(context, safer.summary.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'This is a comparison only; your calendar has not been changed.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _recommendation(ForecastLoadStatus status) => switch (status) {
        ForecastLoadStatus.maintaining =>
          'This schedule should broadly maintain fitness. Add load only if you want to build and your recovery remains stable.',
        ForecastLoadStatus.productive =>
          'The plan creates a useful fitness rise while predicted fatigue remains manageable. Keep the recovery days easy.',
        ForecastLoadStatus.cautious =>
          'The plan can build fitness, but fatigue becomes high. Protect sleep and recovery, and reduce the least important session if readiness falls.',
        ForecastLoadStatus.excessive =>
          'Predicted fatigue is too high relative to fitness. Reduce or replace one demanding session before following this schedule.',
      };

  static String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';

  static Color _outlookColor(BuildContext context, ForecastLoadStatus status) =>
      switch (status) {
        ForecastLoadStatus.maintaining => Colors.lightBlueAccent,
        ForecastLoadStatus.productive => Colors.greenAccent,
        ForecastLoadStatus.cautious => Colors.amberAccent,
        ForecastLoadStatus.excessive => Theme.of(context).colorScheme.error,
      };
}

class _OutlookValue extends StatelessWidget {
  const _OutlookValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _CompactStatusCard extends StatelessWidget {
  const _CompactStatusCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: color.withValues(alpha: .14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _RampStatus {
  const _RampStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String label;
  final String detail;
  final Color color;
  final IconData icon;

  factory _RampStatus.from(double rate) {
    if (rate < 0) {
      return const _RampStatus(
        label: 'Fitness declining',
        detail: 'Red: recent training is below your longer-term level.',
        color: Color(0xFFE64A4A),
        icon: Icons.trending_down,
      );
    }
    if (rate < 2) {
      return const _RampStatus(
        label: 'Building slowly',
        detail: 'Amber: consistent extra load would build fitness faster.',
        color: Color(0xFFFFB020),
        icon: Icons.trending_flat,
      );
    }
    if (rate <= 6) {
      return const _RampStatus(
        label: 'Productive build',
        detail: 'Green: your fitness is increasing at a sustainable rate.',
        color: Color(0xFF19E56F),
        icon: Icons.trending_up,
      );
    }
    if (rate <= 8) {
      return const _RampStatus(
        label: 'Aggressive build',
        detail: 'Amber: fitness is rising quickly; prioritise recovery.',
        color: Color(0xFFFFB020),
        icon: Icons.trending_up,
      );
    }
    return const _RampStatus(
      label: 'Excessive build',
      detail: 'Red: your load is rising very quickly and may be unsustainable.',
      color: Color(0xFFE64A4A),
      icon: Icons.warning_amber,
    );
  }
}
