import 'package:cycle_ready/src/features/insights/application/personal_insights_provider.dart';
import 'package:cycle_ready/src/features/insights/domain/personal_insights.dart';
import 'package:cycle_ready/src/features/insights/application/wellness_period_provider.dart';
import 'package:cycle_ready/src/features/insights/domain/wellness_period_report.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalInsightsScreen extends ConsumerStatefulWidget {
  const PersonalInsightsScreen({super.key});

  @override
  ConsumerState<PersonalInsightsScreen> createState() =>
      _PersonalInsightsScreenState();
}

class _PersonalInsightsScreenState
    extends ConsumerState<PersonalInsightsScreen> {
  WellnessReportPeriod period = WellnessReportPeriod.month;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(personalInsightsProvider);
    final periodReport = ref.watch(wellnessPeriodReportProvider(period));
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Performance Insights',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh insights',
            onPressed: () => ref.invalidate(personalInsightsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(
          onRetry: () => ref.invalidate(personalInsightsProvider),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () => ref.refresh(personalInsightsProvider.future),
          child: _ReportView(
            report: value,
            period: period,
            periodReport: periodReport,
            onPeriodChanged: (value) => setState(() => period = value),
          ),
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView(
      {required this.report,
      required this.period,
      required this.periodReport,
      required this.onPeriodChanged});
  final PersonalInsightsReport report;
  final WellnessReportPeriod period;
  final AsyncValue<WellnessPeriodReport> periodReport;
  final ValueChanged<WellnessReportPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<WellnessReportPeriod>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: WellnessReportPeriod.week, label: Text('7 days')),
              ButtonSegment(
                  value: WellnessReportPeriod.month, label: Text('Month')),
              ButtonSegment(
                  value: WellnessReportPeriod.twelveWeeks,
                  label: Text('12 weeks')),
              ButtonSegment(
                  value: WellnessReportPeriod.year, label: Text('Year')),
            ],
            selected: {period},
            onSelectionChanged: (value) => onPeriodChanged(value.first),
          ),
        ),
        const SizedBox(height: 10),
        periodReport.when(
          loading: () => const Card(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: LinearProgressIndicator())),
          error: (_, __) => const Card(
              child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Period report is unavailable.'))),
          data: (value) => _PeriodSummaryCard(report: value),
        ),
        const SizedBox(height: 16),
        Card(
          color: colors.primaryContainer.withValues(alpha: .55),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'YOUR ROLLING 8 WEEKS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  report.headline,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(report.summary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DataCoverage(report: report),
        const SizedBox(height: 18),
        Text(
          'Four-week comparison',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _LoadComparison(
          previous: report.previousFourWeekLoad,
          current: report.currentFourWeekLoad,
        ),
        const SizedBox(height: 20),
        Text(
          'What your data is saying',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...report.insights.map(_InsightCard.new),
        const SizedBox(height: 12),
        Text(
          'Focus for the next seven days',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var index = 0; index < report.priorities.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(report.priorities[index])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Associations are observations from your own logged data, not proof that one factor caused another. Low-confidence findings need more matching days before guiding training decisions.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.report});
  final WellnessPeriodReport report;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: .45),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.headline,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(report.summary),
            const SizedBox(height: 14),
            Wrap(spacing: 18, runSpacing: 12, children: [
              _PeriodValue('${report.rideCount}', 'RIDES'),
              _PeriodValue(Units.distance(report.distanceMetres), 'DISTANCE'),
              _PeriodValue(_periodDuration(report.durationSeconds), 'TIME'),
              _PeriodValue('${report.load.round()}', 'LOAD'),
              _PeriodValue(
                  report.averageSleepHours == null
                      ? '—'
                      : '${report.averageSleepHours!.toStringAsFixed(1)}h',
                  'AVG SLEEP'),
              _PeriodValue(
                  report.averageHrv == null
                      ? '—'
                      : '${report.averageHrv!.round()} ms',
                  'AVG HRV'),
            ]),
            if (report.bestRide != null) ...[
              const Divider(height: 24),
              Text(
                  'Strongest load: ${report.bestRide!.title} · ${report.bestRide!.load.round()} load',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            const Divider(height: 24),
            Text(report.nutritionDays == 0
                ? 'No nutrition days logged in this period.'
                : '${report.nutritionDays} nutrition days · averages: ${report.averageCarbohydrate!.round()} g carbohydrate, ${report.averageProtein!.round()} g protein and ${report.averageWater!.round()} ml water.'),
            if (report.weightChangeKg != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Weight changed ${report.weightChangeKg! >= 0 ? '+' : ''}${report.weightChangeKg!.toStringAsFixed(1)} kg during this period.')),
            if (report.period == WellnessReportPeriod.twelveWeeks) ...[
              const Divider(height: 24),
              Text('12-week coaching review',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  'You trained in ${report.activeWeeks} of 12 weeks, compared with ${report.previousActiveWeeks} in the preceding block.'),
              const SizedBox(height: 6),
              Text(_recoveryComparison(report)),
              const SizedBox(height: 12),
              for (var index = 0;
                  index < report.coachingPriorities.length;
                  index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child:
                      Text('${index + 1}. ${report.coachingPriorities[index]}'),
                ),
              const SizedBox(height: 4),
              Text(
                '${_confidenceLabel(report.confidence)} confidence · based on ${report.rideCount} rides and available recovery records.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800),
              ),
            ],
            if (report.warning != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(report.warning!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700))),
          ]),
        ),
      );
}

String _recoveryComparison(WellnessPeriodReport report) {
  final currentHrv = report.averageHrv;
  final previousHrv = report.previousAverageHrv;
  final currentRhr = report.averageRestingHeartRate;
  final previousRhr = report.previousAverageRestingHeartRate;
  if (currentHrv == null && currentRhr == null) {
    return 'Recovery direction is unavailable because this block has no HRV or resting heart-rate records.';
  }
  final parts = <String>[];
  if (currentHrv != null && previousHrv != null && previousHrv > 0) {
    final change = (currentHrv / previousHrv - 1) * 100;
    parts.add(
        'HRV is ${change.abs().toStringAsFixed(1)}% ${change >= 0 ? 'higher' : 'lower'}');
  }
  if (currentRhr != null && previousRhr != null) {
    final change = currentRhr - previousRhr;
    parts.add(
        'resting heart rate is ${change.abs().toStringAsFixed(1)} bpm ${change >= 0 ? 'higher' : 'lower'}');
  }
  return parts.isEmpty
      ? 'The preceding block has insufficient recovery data for a trustworthy comparison.'
      : '${parts.join(' and ')} than the preceding 12 weeks.';
}

String _confidenceLabel(WellnessReviewConfidence value) => switch (value) {
      WellnessReviewConfidence.low => 'Early',
      WellnessReviewConfidence.medium => 'Moderate',
      WellnessReviewConfidence.high => 'High',
    };

class _PeriodValue extends StatelessWidget {
  const _PeriodValue(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

String _periodDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = seconds.remainder(3600) ~/ 60;
  return '${hours}h ${minutes}m';
}

class _DataCoverage extends StatelessWidget {
  const _DataCoverage({required this.report});
  final PersonalInsightsReport report;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _CoverageMetric(
              icon: Icons.directions_bike_outlined,
              value: '${report.rideCount}',
              label: 'rides',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CoverageMetric(
              icon: Icons.bedtime_outlined,
              value: '${report.recoveryDays}',
              label: 'recovery days',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CoverageMetric(
              icon: Icons.restaurant_outlined,
              value: '${report.nutritionDays}',
              label: 'fuel days',
            ),
          ),
        ],
      );
}

class _CoverageMetric extends StatelessWidget {
  const _CoverageMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _LoadComparison extends StatelessWidget {
  const _LoadComparison({required this.previous, required this.current});
  final double previous;
  final double current;

  @override
  Widget build(BuildContext context) {
    final maximum = [previous, current].reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LoadBar(
              label: 'Previous 4 weeks',
              value: previous,
              fraction: maximum == 0 ? 0 : previous / maximum,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 14),
            _LoadBar(
              label: 'Latest 4 weeks',
              value: current,
              fraction: maximum == 0 ? 0 : current / maximum,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });
  final String label;
  final double value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${value.round()} load',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
            color: color,
          ),
        ],
      );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.insight);
  final PersonalInsight insight;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (insight.confidence) {
      InsightConfidence.high => ('HIGH CONFIDENCE', const Color(0xFF19D879)),
      InsightConfidence.medium => (
          'MEDIUM CONFIDENCE',
          const Color(0xFF45B6FE)
        ),
      InsightConfidence.low => ('EARLY SIGNAL', const Color(0xFFFFB74D)),
    };
    final icon = switch (insight.kind) {
      'efficiency' => Icons.speed,
      'sleep' => Icons.bedtime_outlined,
      'nutrition' => Icons.restaurant_outlined,
      'recovery' => Icons.monitor_heart_outlined,
      'consistency' => Icons.event_repeat,
      _ => Icons.trending_up,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(insight.message),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '${insight.sampleSize} data points',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Insights could not be calculated.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
