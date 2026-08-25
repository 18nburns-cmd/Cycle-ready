import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/application/athlete_learning_service.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/presentation/workout_profile_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlannedWorkoutDetailScreen extends ConsumerStatefulWidget {
  const PlannedWorkoutDetailScreen({required this.session, super.key});

  final PlannedSession session;

  @override
  ConsumerState<PlannedWorkoutDetailScreen> createState() =>
      _PlannedWorkoutDetailScreenState();
}

class _PlannedWorkoutDetailScreenState
    extends ConsumerState<PlannedWorkoutDetailScreen> {
  final pageController = PageController();
  var page = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final athlete = ref.watch(athleteSettingsProvider).valueOrNull;
    final ftp = athlete?.ftp ?? 200;
    final maxHr = athlete?.maximumHeartRate ?? 190;
    final session = widget.session;
    final response = ref
        .watch(workoutResponseProfileProvider(session.sessionType))
        .valueOrNull;
    final workout = buildStructuredWorkout(
      id: 'planned-${session.day.millisecondsSinceEpoch}',
      day: session.day,
      sessionType: session.sessionType,
      title: session.title,
      requestedMinutes: session.durationMinutes,
      targetLoad: session.targetLoad,
      selectionReason: session.adaptationReason,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Send workouts to Intervals/Garmin',
            onPressed: _sendWorkout,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: (value) => setState(() => page = value),
              children: [
                _Overview(session: session, workout: workout),
                _WhyWorkout(workout: workout, response: response),
                _WorkoutSteps(workout: workout, ftp: ftp, maxHr: maxHr),
              ],
            ),
          ),
          _PageSelector(
            page: page,
            onSelected: (value) => pageController.animateToPage(
              value,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sendWorkout,
                icon: const Icon(Icons.watch_outlined),
                label: const Text('Send workout to Intervals / Garmin'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWorkout() async {
    try {
      final count = await ref
          .read(plannedSessionControllerProvider)
          .publishUpcomingToIntervals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'No uncompleted workouts needed publishing.'
            : 'Sent $count upcoming workout${count == 1 ? '' : 's'}.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout could not be sent: $error')),
      );
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.session, required this.workout});
  final PlannedSession session;
  final StructuredWorkout workout;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        children: [
          Text(session.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Row(children: [
            _TopMetric(
                value: _duration(session.durationMinutes), label: 'Duration'),
            _TopMetric(
                value: _intensity(session.sessionType), label: 'Intensity'),
            _TopMetric(
                value: '${session.targetLoad}', label: 'Training stress'),
          ]),
          const SizedBox(height: 26),
          WorkoutProfileChart(workout: workout, height: 145),
          const SizedBox(height: 24),
          Text('Description',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(workout.description,
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (session.prescription.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(session.prescription,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      );

  static String _duration(int minutes) => minutes < 60
      ? '0:${minutes.toString().padLeft(2, '0')}'
      : '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String _intensity(String type) => switch (type) {
        'intervals' => 'High',
        'tempo' => 'Medium',
        'endurance' => 'Steady',
        'recovery' => 'Easy',
        _ => 'Rest',
      };
}

class _WhyWorkout extends StatelessWidget {
  const _WhyWorkout({required this.workout, required this.response});
  final StructuredWorkout workout;
  final WorkoutResponseSnapshot? response;

  @override
  Widget build(BuildContext context) {
    final rationale = workout.selectionReason.trim();
    final expanded = rationale.length >= 320
        ? rationale
        : '$rationale ${_purposeContext(workout.purpose)} '
            'This session is positioned to create a useful training stimulus while preserving enough capacity for the workouts that follow. '
            'Keep to the prescribed effort: making an easy session hard or turning controlled intervals into a maximal test would change the intended adaptation and increase the recovery cost.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      children: [
        Text('Why this workout?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        Text(expanded,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: 24),
        _ReasonCard(
          icon: Icons.verified_outlined,
          title: 'Recommendation confidence',
          text: '${(workout.confidence * 100).round()}%. This reflects the '
              'quality and completeness of the athlete data available when the workout was selected.',
        ),
        _ReasonCard(
          icon: Icons.trending_up,
          title: 'Expected benefit',
          text: workout.expectedAdaptation,
        ),
        _ReasonCard(
          icon: Icons.psychology_outlined,
          title: 'Coach notes',
          text: workout.coachNotes,
        ),
        _ReasonCard(
          icon: Icons.battery_charging_full,
          title: 'Recovery cost',
          text: 'Estimated fatigue ${workout.estimatedFatigue}/100 with about '
              '${workout.estimatedRecoveryHours} hours before another demanding session.',
        ),
        if (response != null)
          _ReasonCard(
            icon: Icons.auto_graph,
            title: 'What CycleReady has learned',
            text: _responseText(response!),
          ),
      ],
    );
  }

  String _responseText(WorkoutResponseSnapshot value) {
    return '${value.coachingInsight} Based on ${value.sampleCount} similar '
        'session${value.sampleCount == 1 ? '' : 's'}, you average '
        '${(value.averageDurationRatio * 100).round()}% of planned duration '
        'and ${(value.averageLoadRatio * 100).round()}% of target load.';
  }

  String _purposeContext(WorkoutPurpose purpose) => switch (purpose) {
        WorkoutPurpose.recovery =>
          'Recovery is scheduled here so accumulated fatigue can fall and the previous training stimulus can be absorbed before more demanding work.',
        WorkoutPurpose.endurance =>
          'Aerobic endurance is the foundation that lets you repeat quality sessions, resist fatigue late in rides and recover more effectively between efforts.',
        WorkoutPurpose.tempo ||
        WorkoutPurpose.sweetSpot =>
          'This sustained work bridges endurance and threshold, improving your ability to hold useful power without the recovery demand of maximal intervals.',
        WorkoutPurpose.threshold =>
          'Threshold work is used here to increase sustainable power and make race-pace efforts more economical.',
        WorkoutPurpose.vo2Max =>
          'VO2 work is placed selectively because it provides a powerful aerobic stimulus but carries a substantial recovery cost.',
        WorkoutPurpose.anaerobic ||
        WorkoutPurpose.sprint ||
        WorkoutPurpose.neuromuscular =>
          'Short high-power work develops recruitment and repeatability that steady riding alone cannot provide.',
        WorkoutPurpose.cadence =>
          'Cadence work improves coordination and pedalling economy without relying only on additional load.',
        WorkoutPurpose.climbing ||
        WorkoutPurpose.strengthEndurance =>
          'This develops torque and fatigue resistance for sustained climbing and harder real-world terrain.',
        WorkoutPurpose.raceSimulation =>
          'Race-specific changes of pace rehearse the demands you will need to manage in your target event.',
      };
}

class _WorkoutSteps extends StatelessWidget {
  const _WorkoutSteps({
    required this.workout,
    required this.ftp,
    required this.maxHr,
  });
  final StructuredWorkout workout;
  final int ftp;
  final int maxHr;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text('Workout steps',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...workout.steps.map((step) => _StepCard(
                step: step,
                ftp: ftp,
                maxHr: maxHr,
              )),
        ],
      );
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.ftp, required this.maxHr});
  final WorkoutStep step;
  final int ftp;
  final int maxHr;

  @override
  Widget build(BuildContext context) {
    final hard = step.powerHighPercent >= 88;
    final color = hard ? const Color(0xFFFFC94D) : const Color(0xFF46D3E6);
    final minutes = (step.durationSeconds / 60).round();
    final lowPower = (ftp * step.powerLowPercent / 100).round();
    final highPower = (ftp * step.powerHighPercent / 100).round();
    final lowHr = step.heartRateLowPercent == null
        ? null
        : (maxHr * step.heartRateLowPercent! / 100).round();
    final highHr = step.heartRateHighPercent == null
        ? null
        : (maxHr * step.heartRateHighPercent! / 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF102126)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(step.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900))),
            if (step.repetitions > 1) Chip(label: Text('${step.repetitions}×')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StepValue(value: '${step.rpe}', label: 'RPE'),
            _StepValue(value: '$minutes min', label: 'Each effort'),
          ]),
          const Divider(color: Color(0x44102126)),
          Row(children: [
            _StepValue(
                value: lowHr == null ? 'By feel' : '$lowHr–$highHr',
                label: 'Heart rate'),
            _StepValue(value: '$lowPower–$highPower W', label: 'Power'),
          ]),
        ]),
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  const _TopMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.signal_cellular_alt,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(height: 5),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

class _StepValue extends StatelessWidget {
  const _StepValue({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      );
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard(
      {required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(text),
                ])),
          ]),
        ),
      );
}

class _PageSelector extends StatelessWidget {
  const _PageSelector({required this.page, required this.onSelected});
  final int page;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            3,
            (index) => IconButton(
                  tooltip: const [
                    'Workout',
                    'Why this workout',
                    'Workout steps'
                  ][index],
                  onPressed: () => onSelected(index),
                  icon: Icon(
                    const [
                      Icons.trending_up,
                      Icons.help_outline,
                      Icons.view_agenda_outlined
                    ][index],
                    color: index == page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                )),
      );
}
