import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/activities/application/post_ride_feedback_controller.dart';
import 'package:cycle_ready/src/features/activities/application/power_curve_provider.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/coach_ai_report.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_debrief.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_feedback.dart';
import 'package:cycle_ready/src/features/activities/domain/power_breakthrough.dart';
import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PostRideDebriefScreen extends ConsumerWidget {
  const PostRideDebriefScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides =
        ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
    final ride = rides.where((item) => item.id == id).firstOrNull;
    final settings = ref.watch(athleteSettingsProvider).valueOrNull;
    final samples = ref.watch(activityDetailSamplesProvider(id));
    final criticalPower = ref.watch(criticalPowerProvider);
    final powerCurve = ref.watch(powerCurveProvider).valueOrNull;
    if (ride == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final result = buildPostRideDebrief(
      ride: _debriefRide(ride),
      history: rides.map(_debriefRide),
      weightKg: settings?.weightKg ?? 70,
    );
    final day = DateTime(
      ride.startedAt.year,
      ride.startedAt.month,
      ride.startedAt.day,
    );
    final planned = ref
        .watch(plannedSessionsProvider((start: day, end: day)))
        .valueOrNull
        ?.firstOrNull;
    final feedback = ref.watch(postRideFeedbackProvider(id)).valueOrNull;
    final storedReport = ref.watch(rideCoachReportProvider(id)).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Post-ride debrief')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_circle, size: 36),
                  const SizedBox(height: 12),
                  Text(result.headline,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(result.summary),
                  const SizedBox(height: 16),
                  Wrap(spacing: 18, runSpacing: 10, children: [
                    _CompactStat(
                        'DISTANCE', Units.distance(ride.distanceMetres)),
                    _CompactStat('TIME', _duration(ride.durationSeconds)),
                    _CompactStat('LOAD', ride.trainingLoad?.toString() ?? '—'),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DebriefCard(
            icon: Icons.query_stats,
            title: result.loadLabel,
            body: result.loadComparison,
            footnote: result.comparisonRideCount == 0
                ? 'Building your personal baseline'
                : 'Compared with ${result.comparisonRideCount} rides from the previous eight weeks',
          ),
          _DebriefCard(
            icon: Icons.favorite_outline,
            title: 'Aerobic efficiency',
            body: result.efficiencyComparison,
          ),
          if (storedReport != null)
            _DebriefCard(
              icon: Icons.history_edu_outlined,
              title: 'Saved coaching record',
              body: '${storedReport.summary}\n\n'
                  'Tomorrow: ${storedReport.tomorrowRecommendation}\n'
                  'Focus: ${storedReport.keyFocus}',
              footnote: storedReport.plannedTitle == null
                  ? storedReport.confidenceReason
                  : 'Compared with ${storedReport.plannedTitle}. ${storedReport.confidenceReason}',
            ),
          samples.when(
            data: (values) {
              final metrics = calculateAdvancedRideMetrics(
                durationSeconds: ride.durationSeconds,
                ftp: settings?.ftp ?? 200,
                criticalPower: criticalPower?.watts,
                samples: values.map((sample) => (
                      elapsedSeconds: sample.elapsedSeconds,
                      power: sample.power,
                      heartRate: sample.heartRate,
                      cadence: sample.cadence,
                    )),
              );
              final analysis = analyseRide(
                durationSeconds: ride.durationSeconds,
                distanceMetres: ride.distanceMetres,
                ftp: settings?.ftp ?? 200,
                maximumHeartRate: settings?.maximumHeartRate ?? 190,
                weightKg: settings?.weightKg ?? 70,
                averagePower: ride.averagePower,
                averageHeartRate: ride.averageHeartRate,
                normalisedPower: ride.normalisedPower,
                samples: values.map((sample) => (
                      elapsedSeconds: sample.elapsedSeconds,
                      power: sample.power,
                      heartRate: sample.heartRate,
                    )),
              );
              final priorPowerRideCount = rides.where((item) {
                return item.id != ride.id &&
                    item.averagePower != null &&
                    item.startedAt.isBefore(ride.startedAt) &&
                    item.startedAt.isAfter(
                      ride.startedAt.subtract(const Duration(days: 56)),
                    );
              }).length;
              final breakthroughs = detectPowerBreakthroughs(
                activityId: ride.id,
                rollingCurve: powerCurve ?? const [],
                priorPowerRideCount: priorPowerRideCount,
              );
              final coach = buildCoachAiReport(
                ride: _debriefRide(ride),
                history: rides.map(_debriefRide),
                advanced: metrics,
                analysis: analysis,
                ftp: settings?.ftp ?? 200,
                weightKg: settings?.weightKg ?? 70,
                plannedType: planned?.sessionType,
                plannedMinutes: planned?.durationMinutes,
                plannedLoad: planned?.targetLoad,
                perceivedEffort: feedback?.perceivedEffort,
                legFatigue: feedback?.legFatigue,
                discomfort: feedback?.discomfort,
                enjoyment: feedback?.enjoyment,
                breakthroughs: breakthroughs,
              );
              return Column(children: [
                if (breakthroughs.isNotEmpty)
                  _BreakthroughCard(breakthroughs: breakthroughs),
                _RideIntelligenceCard(
                  metrics: metrics,
                  analysis: analysis,
                  usesCriticalPower: criticalPower != null,
                ),
                _CoachReportView(report: coach),
              ]);
            },
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: LinearProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _PostRideFeedbackCard(activityId: id),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.push('/activities/$id'),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('View full ride analysis'),
          ),
        ],
      ),
    );
  }
}

class _BreakthroughCard extends StatelessWidget {
  const _BreakthroughCard({required this.breakthroughs});

  final List<PowerBreakthrough> breakthroughs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bolt, color: colors.onTertiaryContainer),
              const SizedBox(width: 10),
              Text(
                'New eight-week power best',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: breakthroughs
                  .map((item) => Chip(
                        avatar: const Icon(Icons.trending_up, size: 18),
                        label: Text('${item.label}  ${item.watts} W'),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Compared with power recorded during your previous eight weeks. '
              'This is a rolling best, not an all-time personal record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RideIntelligenceCard extends StatelessWidget {
  const _RideIntelligenceCard({
    required this.metrics,
    required this.analysis,
    required this.usesCriticalPower,
  });

  final AdvancedRideMetrics metrics;
  final RideAnalysis analysis;
  final bool usesCriticalPower;

  @override
  Widget build(BuildContext context) {
    final drift = metrics.aerobicDecouplingPercent;
    final pacing = metrics.secondHalfPowerChangePercent;
    final highlights = <String>[
      if (drift != null)
        drift <= 5
            ? 'Aerobic efficiency stayed controlled (${drift.toStringAsFixed(1)}% drift).'
            : 'Aerobic drift reached ${drift.toStringAsFixed(1)}%; review pacing, fuel, fluid and heat.',
      if (pacing != null)
        pacing >= -3
            ? 'Power held up well in the second half (${pacing >= 0 ? '+' : ''}${pacing.toStringAsFixed(1)}%).'
            : 'Second-half power fell ${pacing.abs().toStringAsFixed(1)}%, showing some pacing fade.',
      if (metrics.matchesBurned > 0)
        '${metrics.matchesBurned} sustained efforts exceeded ${usesCriticalPower ? 'Critical Power' : '120% of FTP'}, costing ${metrics.matchWorkKilojoules.toStringAsFixed(1)} kJ above the model threshold.',
      if (metrics.matchesBurned == 0 && metrics.powerCoveragePercent >= 70)
        'No sustained efforts above ${usesCriticalPower ? 'Critical Power' : '120% of FTP'} were detected.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.auto_graph)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride intelligence',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Text('The signals that mattered most'),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _IntelligenceMetric(
                label: 'MATCHES', value: '${metrics.matchesBurned}'),
            _IntelligenceMetric(
                label: 'DRIFT',
                value: drift == null ? '—' : '${drift.toStringAsFixed(1)}%'),
            _IntelligenceMetric(
                label: 'PACING',
                value: pacing == null
                    ? '—'
                    : '${pacing >= 0 ? '+' : ''}${pacing.toStringAsFixed(1)}%'),
            _IntelligenceMetric(
                label: 'VARIABILITY',
                value: analysis.variabilityIndex?.toStringAsFixed(2) ?? '—'),
          ]),
          const SizedBox(height: 12),
          if (highlights.isEmpty)
            const Text(
                'More complete power and heart-rate streams are needed for these insights.')
          else
            ...highlights.map((text) => Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.arrow_right, size: 18),
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(text)),
                    ],
                  ),
                )),
          if (metrics.moments.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'MOMENTS THAT MATTERED',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            ...metrics.moments.map((moment) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timeline),
                  title: Text(
                      '${_momentTime(moment.startSeconds)}–${_momentTime(moment.endSeconds)} · ${moment.title}'),
                  subtitle: Text(moment.detail),
                )),
          ],
        ]),
      ),
    );
  }
}

String _momentTime(int seconds) =>
    '${seconds ~/ 60}:${seconds.remainder(60).toString().padLeft(2, '0')}';

class _IntelligenceMetric extends StatelessWidget {
  const _IntelligenceMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

class _CoachReportView extends StatelessWidget {
  const _CoachReportView({required this.report});
  final CoachAiReport report;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _CoachVerdictCard(verdict: report.verdict),
          _CoachSection(
            icon: Icons.record_voice_over_outlined,
            title: 'Overall Coach Summary',
            body: report.summary,
            initiallyExpanded: true,
          ),
          _CoachSection(
            icon: Icons.adjust,
            title: 'Session Objective',
            body: report.objective,
          ),
          _CoachSection(
            icon: Icons.fact_check_outlined,
            title:
                'Workout Execution · ${report.executionScore.toStringAsFixed(1)}/10',
            body: report.execution,
          ),
          _CoachSection(
            icon: Icons.bolt,
            title: 'Power Analysis',
            body: report.power,
          ),
          _CoachSection(
            icon: Icons.monitor_heart_outlined,
            title: 'Heart Rate Analysis',
            body: report.heartRate,
          ),
          _CoachSection(
            icon: Icons.sync,
            title: 'Cadence Analysis',
            body: report.cadence,
          ),
          _CoachSection(
            icon: Icons.battery_2_bar_outlined,
            title: 'Fatigue Analysis',
            body: report.fatigue,
          ),
          _CoachSection(
            icon: Icons.trending_up,
            title: 'Adaptation Analysis',
            body: report.adaptation,
          ),
          _CoachSection(
            icon: Icons.compare_arrows,
            title: 'Comparison With Previous Sessions',
            body: report.comparison,
          ),
          _CoachSection(
            icon: Icons.bedtime_outlined,
            title: 'Recovery Advice',
            body: report.recovery,
          ),
          _CoachRecommendationCard(report: report),
          _CoachSection(
            icon: Icons.verified_outlined,
            title: 'Confidence Rating · ${_confidenceLabel(report.confidence)}',
            body: report.confidenceReason,
          ),
          const SizedBox(height: 8),
        ],
      );

  static String _confidenceLabel(CoachConfidence value) => switch (value) {
        CoachConfidence.high => 'High',
        CoachConfidence.medium => 'Medium',
        CoachConfidence.low => 'Low',
      };
}

class _CoachVerdictCard extends StatelessWidget {
  const _CoachVerdictCard({required this.verdict});
  final CoachVerdict verdict;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_score, size: 28),
                  const SizedBox(width: 9),
                  Text(
                    "COACH'S VERDICT",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _VerdictRow('Session quality', verdict.sessionQuality),
              _VerdictRow('Training benefit', verdict.trainingBenefit),
              _VerdictRow('Recovery demand', verdict.recoveryDemand),
              _VerdictRow("Tomorrow's recommendation", verdict.tomorrow),
              const Divider(height: 24),
              Text(
                'KEY FOCUS FOR NEXT RIDE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(verdict.keyFocus),
            ],
          ),
        ),
      );
}

class _VerdictRow extends StatelessWidget {
  const _VerdictRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _CoachSection extends StatelessWidget {
  const _CoachSection({
    required this.icon,
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(width: double.infinity, child: Text(body))],
        ),
      );
}

class _CoachRecommendationCard extends StatelessWidget {
  const _CoachRecommendationCard({required this.report});
  final CoachAiReport report;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.psychology_outlined),
          title: const Text(
            'Coach Recommendation',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RecommendationHeading('THREE THINGS DONE WELL'),
            ...report.doneWell.map((item) => _RecommendationItem(item)),
            const SizedBox(height: 10),
            const _RecommendationHeading('THREE IMPROVEMENTS'),
            ...report.improvements.map((item) => _RecommendationItem(item)),
            const SizedBox(height: 10),
            const _RecommendationHeading('ONE PRIORITY'),
            _RecommendationItem(report.verdict.keyFocus),
          ],
        ),
      );
}

class _RecommendationHeading extends StatelessWidget {
  const _RecommendationHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 5),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      );
}

class _RecommendationItem extends StatelessWidget {
  const _RecommendationItem(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _PostRideFeedbackCard extends ConsumerWidget {
  const _PostRideFeedbackCard({required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(postRideFeedbackProvider(activityId));
    return feedback.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (_, __) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.rate_review_outlined)),
          title: const Text('How did that feel?'),
          subtitle: const Text('Feedback could not be loaded.'),
          trailing: const Icon(Icons.refresh),
          onTap: () => ref.invalidate(postRideFeedbackProvider(activityId)),
        ),
      ),
      data: (saved) {
        if (saved == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(child: Icon(Icons.rate_review_outlined)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('How did that feel?',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'Add your effort, leg fatigue and enjoyment so future coaching can learn from the ride.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showFeedbackSheet(context, ref, activityId, null),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('Add ride feedback'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final interpretation = interpretPostRideFeedback(
          PostRideFeedbackInput(
            perceivedEffort: saved.perceivedEffort,
            legFatigue: saved.legFatigue,
            enjoyment: saved.enjoyment,
            discomfort: saved.discomfort,
          ),
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(child: Icon(Icons.check_circle_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Your ride feedback',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () =>
                        _showFeedbackSheet(context, ref, activityId, saved),
                    child: const Text('Edit'),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _FeedbackChip('Effort', saved.perceivedEffort),
                  _FeedbackChip('Legs', saved.legFatigue),
                  _FeedbackChip('Enjoyment', saved.enjoyment),
                  _FeedbackChip('Discomfort', saved.discomfort),
                ]),
                const SizedBox(height: 12),
                Text(interpretation),
                if (saved.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('“${saved.notes}”',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$label $value/10'),
        avatar: Icon(
          label == 'Enjoyment' ? Icons.sentiment_satisfied_alt : Icons.speed,
          size: 17,
        ),
      );
}

Future<void> _showFeedbackSheet(
  BuildContext parentContext,
  WidgetRef ref,
  String activityId,
  PostRideFeedback? saved,
) async {
  var effort = saved?.perceivedEffort ?? 5;
  var legs = saved?.legFatigue ?? 5;
  var enjoyment = saved?.enjoyment ?? 7;
  var discomfort = saved?.discomfort ?? 0;
  final notes = TextEditingController(text: saved?.notes ?? '');
  final shouldSave = await showModalBottomSheet<bool>(
    context: parentContext,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Post-ride feedback',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('1 is low and 10 is very high.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              _FeedbackSlider(
                label: 'Perceived effort',
                value: effort,
                low: 'Easy',
                high: 'Maximal',
                onChanged: (value) =>
                    setModalState(() => effort = value.round()),
              ),
              _FeedbackSlider(
                label: 'Leg fatigue',
                value: legs,
                low: 'Fresh',
                high: 'Exhausted',
                onChanged: (value) => setModalState(() => legs = value.round()),
              ),
              _FeedbackSlider(
                label: 'Enjoyment',
                value: enjoyment,
                low: 'Poor',
                high: 'Brilliant',
                onChanged: (value) =>
                    setModalState(() => enjoyment = value.round()),
              ),
              _FeedbackSlider(
                label: 'Pain or discomfort',
                value: discomfort,
                low: 'None',
                high: 'Severe',
                minimum: 0,
                onChanged: (value) =>
                    setModalState(() => discomfort = value.round()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'Strong legs, knee niggle, poor fuelling…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (shouldSave == true) {
    await ref.read(postRideFeedbackControllerProvider).save(
          activityId: activityId,
          perceivedEffort: effort,
          legFatigue: legs,
          enjoyment: enjoyment,
          discomfort: discomfort,
          notes: notes.text,
        );
    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('Ride feedback saved.')),
      );
    }
  }
  await Future<void>.delayed(const Duration(milliseconds: 350));
  notes.dispose();
}

class _FeedbackSlider extends StatelessWidget {
  const _FeedbackSlider({
    required this.label,
    required this.value,
    required this.low,
    required this.high,
    required this.onChanged,
    this.minimum = 1,
  });

  final String label;
  final int value;
  final String low;
  final String high;
  final double minimum;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text('$value/10'),
          ]),
          Slider(
            value: value.toDouble(),
            min: minimum,
            max: 10,
            divisions: (10 - minimum).round(),
            label: '$value',
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(low, style: Theme.of(context).textTheme.bodySmall),
              Text(high, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
        ],
      );
}

DebriefRide _debriefRide(Activity ride) => DebriefRide(
      id: ride.id,
      startedAt: ride.startedAt,
      durationSeconds: ride.durationSeconds,
      trainingLoad: ride.trainingLoad,
      averagePower: ride.averagePower,
      averageHeartRate: ride.averageHeartRate,
      title: ride.title,
    );

class _CompactStat extends StatelessWidget {
  const _CompactStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _DebriefCard extends StatelessWidget {
  const _DebriefCard({
    required this.icon,
    required this.title,
    required this.body,
    this.footnote,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(body),
                  if (footnote != null) ...[
                    const SizedBox(height: 8),
                    Text(footnote!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ]),
        ),
      );
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}
