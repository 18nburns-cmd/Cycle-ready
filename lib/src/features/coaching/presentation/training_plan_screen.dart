import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/data/planned_session_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/domain/structured_workout.dart';
import 'package:cycle_ready/src/features/coaching/domain/planned_workout_outcome.dart';
import 'package:cycle_ready/src/features/coaching/presentation/workout_profile_chart.dart';
import 'package:go_router/go_router.dart';

class TrainingPlanScreen extends ConsumerStatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  ConsumerState<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends ConsumerState<TrainingPlanScreen> {
  late DateTime month;
  late DateTime selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    selectedDay = DateTime(now.year, now.month, now.day);
  }

  CalendarRange get range => (
        start: month,
        end: DateTime(month.year, month.month + 1, 0),
      );

  @override
  Widget build(BuildContext context) {
    final storedSessions =
        ref.watch(plannedSessionsProvider(range)).valueOrNull ?? const [];
    final rides =
        ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
    final strengthSessions = ref.watch(strengthSessionsProvider).valueOrNull ??
        const <StrengthSession>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final thisWeekRides = rides
        .where((ride) =>
            !ride.startedAt.isBefore(weekStart) &&
            ride.startedAt.isBefore(weekEnd))
        .toList();
    final completedByDay = <int, List<Activity>>{};
    for (final ride in rides.where((ride) =>
        ride.startedAt.year == month.year &&
        ride.startedAt.month == month.month)) {
      completedByDay.putIfAbsent(ride.startedAt.day, () => []).add(ride);
    }
    final strengthByDay = <int, List<StrengthSession>>{};
    for (final session in strengthSessions.where((session) {
      final completedAt = session.completedAt;
      return completedAt != null &&
          completedAt.year == month.year &&
          completedAt.month == month.month;
    })) {
      strengthByDay
          .putIfAbsent(session.completedAt!.day, () => [])
          .add(session);
    }
    final byDay = {
      for (final session in storedSessions) session.day.day: session
    };
    final selected =
        selectedDay.month == month.month ? byDay[selectedDay.day] : null;
    final completed = selectedDay.month == month.month
        ? completedByDay[selectedDay.day] ?? const <Activity>[]
        : const <Activity>[];
    final completedStrength = selectedDay.month == month.month
        ? strengthByDay[selectedDay.day] ?? const <StrengthSession>[]
        : const <StrengthSession>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Plan',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Cycling availability',
            onPressed: _editAvailability,
            icon: const Icon(Icons.schedule_outlined),
          ),
          IconButton(
            tooltip: 'Goal event and periodisation',
            onPressed: () => context.push('/event-goal'),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: 'Send workouts to Intervals/Garmin',
            onPressed: _publishToGarmin,
            icon: const Icon(Icons.watch_outlined),
          ),
          IconButton(
            tooltip: 'Build adaptive plan',
            onPressed: _buildAdaptivePlan,
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      floatingActionButton: completed.isNotEmpty ||
              completedStrength.isNotEmpty ||
              selected != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editSession(null),
              icon: const Icon(Icons.add),
              label: const Text('Add workout'),
            ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          _WeeklyRideSummary(rides: thisWeekRides),
          const SizedBox(height: 18),
          _MonthHeader(
            month: month,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 18),
          _CalendarGrid(
            month: month,
            selectedDay: selectedDay,
            sessions: byDay,
            completedDays: {
              ...completedByDay.keys,
              ...strengthByDay.keys,
            },
            strengthDays: strengthByDay.keys.toSet(),
            onSelected: (day) => _openCalendarDay(
              day,
              byDay[day.day],
              completedByDay[day.day] ?? const <Activity>[],
              strengthByDay[day.day] ?? const <StrengthSession>[],
            ),
            onLongPressEntry: (day) => _showCalendarEntryActions(
              day,
              byDay[day.day],
              strengthByDay[day.day] ?? const <StrengthSession>[],
            ),
          ),
          const SizedBox(height: 24),
          Text(_fullDate(selectedDay),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (completed.isNotEmpty || completedStrength.isNotEmpty) ...[
            if (completed.isNotEmpty)
              _CompletedDayCard(rides: completed, planned: selected),
            ...completedStrength.map(
              (session) => _CompletedStrengthCard(
                session: session,
                onDelete: () => _confirmDeleteStrengthSession(session),
              ),
            ),
          ] else if (selected == null)
            _EmptyDay(onAdd: () => _editSession(null))
          else
            _PlannedDayCard(
              session: selected,
              onDelete: () => _confirmDeleteSession(selected),
            ),
        ],
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      month = DateTime(month.year, month.month + offset);
      selectedDay = DateTime(month.year, month.month, 1);
    });
  }

  Future<void> _editSession(PlannedSession? existing) async {
    var type = existing == null
        ? SessionType.endurance
        : SessionType.values.firstWhere(
            (value) => value.name == existing.sessionType,
            orElse: () => SessionType.endurance,
          );
    var duration = existing?.durationMinutes ?? 60;
    var load = existing?.targetLoad ?? 40;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    existing == null ? 'Plan workout' : 'Edit workout',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              DropdownButtonFormField<SessionType>(
                initialValue: type,
                decoration: const InputDecoration(
                    labelText: 'Session type', border: OutlineInputBorder()),
                items: SessionType.values
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(_typeLabel(value))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setSheetState(() {
                    type = value;
                    final defaults = _defaults(value);
                    duration = defaults.$1;
                    load = defaults.$2;
                  });
                },
              ),
              const SizedBox(height: 18),
              _SliderSetting(
                label: 'Duration',
                valueLabel: duration == 0 ? 'Rest' : '$duration min',
                value: duration.toDouble(),
                max: 240,
                divisions: 16,
                onChanged: type == SessionType.rest
                    ? null
                    : (value) => setSheetState(() => duration = value.round()),
              ),
              _SliderSetting(
                label: 'Planned load',
                valueLabel: '$load',
                value: load.toDouble(),
                max: 150,
                divisions: 30,
                onChanged: type == SessionType.rest
                    ? null
                    : (value) => setSheetState(() => load = value.round()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save to calendar'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await ref.read(plannedSessionControllerProvider).save(
          day: selectedDay,
          type: type,
          durationMinutes: type == SessionType.rest ? 0 : duration,
          targetLoad: type == SessionType.rest ? 0 : load,
        );
  }

  Future<void> _showSessionActions(PlannedSession session) async {
    setState(() => selectedDay = session.day);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                session.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(_fullDate(session.day)),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete from calendar',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await _confirmDeleteSession(session);
    }
  }

  Future<void> _openCalendarDay(
    DateTime day,
    PlannedSession? planned,
    List<Activity> rides,
    List<StrengthSession> strengthSessions,
  ) async {
    setState(() => selectedDay = day);
    if (planned == null && rides.isEmpty && strengthSessions.isEmpty) return;
    if (planned != null) {
      await context.push('/planned-workout', extra: planned);
      return;
    }
    final athlete = await ref.read(athleteProfileProvider.future);
    if (!mounted) return;
    final structured = planned == null || planned.durationMinutes <= 0
        ? null
        : buildStructuredWorkout(
            id: 'calendar-${planned.day.millisecondsSinceEpoch}',
            day: planned.day,
            sessionType: planned.sessionType,
            title: planned.title,
            requestedMinutes: planned.durationMinutes,
            targetLoad: planned.targetLoad,
            selectionReason: planned.adaptationReason,
          );

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullDate(day),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (planned != null) ...[
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: _typeColor(planned.sessionType)
                          .withValues(alpha: .18),
                      child: Icon(
                        planned.sessionType == SessionType.rest.name
                            ? Icons.self_improvement
                            : Icons.directions_bike,
                        color: _typeColor(planned.sessionType),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(planned.title,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(planned.durationMinutes == 0
                              ? 'Recovery day'
                              : '${planned.durationMinutes} minutes · planned load ${planned.targetLoad}'),
                        ],
                      ),
                    ),
                  ]),
                  if (structured != null) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _WorkoutHeadlineMetric(
                            icon: Icons.schedule,
                            value: _compactDuration(planned.durationMinutes),
                            label: 'DURATION',
                          ),
                        ),
                        Expanded(
                          child: _WorkoutHeadlineMetric(
                            icon: Icons.signal_cellular_alt,
                            value: _intensityLabel(planned.sessionType),
                            label: 'INTENSITY',
                          ),
                        ),
                        Expanded(
                          child: _WorkoutHeadlineMetric(
                            icon: Icons.stacked_bar_chart,
                            value: '${planned.targetLoad}',
                            label: 'TRAINING STRESS',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    WorkoutProfileChart(workout: structured, height: 118),
                  ],
                  if (planned.prescription.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('SESSION',
                        style: Theme.of(sheetContext).textTheme.labelMedium),
                    const SizedBox(height: 5),
                    Text(planned.prescription),
                  ],
                  if (structured != null) ...[
                    const SizedBox(height: 12),
                    Text(structured.description),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _PersonalTarget(
                            value: '${athlete.ftp}',
                            unit: 'W',
                            label: 'CURRENT FTP',
                          ),
                        ),
                        Expanded(
                          child: _PersonalTarget(
                            value:
                                '${(athlete.maximumHeartRate * .88).round()}',
                            unit: 'bpm',
                            label: 'THRESHOLD HR',
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (planned.adaptationReason.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.auto_awesome, size: 18),
                            SizedBox(width: 7),
                            Text('WHY THIS SESSION',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 7),
                          Text(planned.adaptationReason),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'delete'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove from calendar'),
                    ),
                  ),
                ],
                if (rides.isNotEmpty) ...[
                  if (planned != null) const Divider(height: 32),
                  Text('COMPLETED RIDES',
                      style: Theme.of(sheetContext).textTheme.labelMedium),
                  ...rides.map((ride) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x3319E56F),
                          child: Icon(Icons.check, color: Color(0xFF19E56F)),
                        ),
                        title: Text(ride.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${Units.distance(ride.distanceMetres)} · '
                          '${ride.durationSeconds ~/ 60} min'
                          '${ride.trainingLoad == null ? '' : ' · load ${ride.trainingLoad}'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.pop(sheetContext, 'ride:${ride.id}'),
                      )),
                ],
                if (strengthSessions.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('COMPLETED STRENGTH & MOBILITY',
                      style: Theme.of(sheetContext).textTheme.labelMedium),
                  ...strengthSessions.map((session) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(session.routineName.startsWith('Mobility')
                            ? Icons.self_improvement
                            : Icons.fitness_center),
                        title: Text(session.routineName),
                        subtitle: const Text('Completed'),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete' && planned != null) {
      await _confirmDeleteSession(planned);
    } else if (action.startsWith('ride:')) {
      context.push('/activities/${action.substring(5)}');
    }
  }

  String _compactDuration(int minutes) => minutes < 60
      ? '0:${minutes.toString().padLeft(2, '0')}'
      : '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _intensityLabel(String type) => switch (type) {
        'intervals' => 'Hard',
        'tempo' => 'Moderate',
        'endurance' => 'Steady',
        'recovery' => 'Easy',
        _ => 'Rest',
      };

  Future<void> _showCalendarEntryActions(
    DateTime day,
    PlannedSession? planned,
    List<StrengthSession> strengthSessions,
  ) async {
    setState(() => selectedDay = day);
    if (strengthSessions.isEmpty && planned != null) {
      await _showSessionActions(planned);
      return;
    }
    final selected = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fullDate(day),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (planned != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_bike_outlined),
                  title: Text(planned.title),
                  subtitle: const Text('Planned workout'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, planned),
                ),
              ...strengthSessions.map(
                (session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session.routineName.startsWith('Mobility')
                        ? Icons.self_improvement
                        : Icons.fitness_center,
                  ),
                  title: Text(session.routineName),
                  subtitle: const Text('Completed session'),
                  trailing: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onTap: () => Navigator.pop(context, session),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected is PlannedSession) {
      await _showSessionActions(selected);
    } else if (selected is StrengthSession) {
      await _confirmDeleteStrengthSession(selected);
    }
  }

  Future<void> _confirmDeleteStrengthSession(StrengthSession session) async {
    final isMobility = session.routineName.startsWith('Mobility');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isMobility ? 'mobility' : 'strength'} session?'),
        content: Text(
          '${session.routineName} and its logged exercises will be permanently '
          'removed. Imported rides will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(strengthControllerProvider).deleteSession(session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${session.routineName} removed.')),
    );
  }

  Future<void> _confirmDeleteSession(PlannedSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          '${session.title} will be removed from ${_fullDate(session.day)}. '
          'Completed ride and gym data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(plannedSessionControllerProvider).delete(session.day);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${session.title} removed from the calendar.')),
    );
  }

  Future<void> _buildAdaptivePlan() async {
    final current =
        await ref.read(plannedSessionRepositoryProvider).getPreferences();
    if (!mounted) return;
    var goal = TrainingGoal.values.firstWhere(
      (value) => value.name == current.goal,
      orElse: () => TrainingGoal.generalFitness,
    );
    var days = current.daysPerWeek;
    var longDay = current.longRideWeekday;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Build adaptive plan',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'CycleReady will create a four-week block from your FTP, readiness, rolling load, completed rides, gym sessions and post-ride feedback. Three progressive weeks lead into a deliberate recovery week. Missed workouts, sore legs, discomfort and excess fatigue automatically reduce upcoming intensity.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<TrainingGoal>(
                initialValue: goal,
                decoration: const InputDecoration(
                    labelText: 'Primary goal', border: OutlineInputBorder()),
                items: TrainingGoal.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_goalLabel(value)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => goal = value);
                },
              ),
              const SizedBox(height: 16),
              _SliderSetting(
                label: 'Training days each week',
                valueLabel: '$days days',
                value: days.toDouble(),
                min: 2,
                max: 6,
                divisions: 4,
                onChanged: (value) =>
                    setSheetState(() => days = value.round().clamp(2, 6)),
              ),
              DropdownButtonFormField<int>(
                initialValue: longDay,
                decoration: const InputDecoration(
                    labelText: 'Long ride day', border: OutlineInputBorder()),
                items: List.generate(
                  7,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(_weekdays[index]),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setSheetState(() => longDay = value);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate four-week block'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(plannedSessionControllerProvider);
    await controller.savePreferences(
      goal: goal,
      daysPerWeek: days,
      longRideWeekday: longDay,
    );
    final count = await controller.generateAdaptivePlan();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated $count future structured sessions.')),
      );
    }
  }

  Future<void> _editAvailability() async {
    final controller = ref.read(plannedSessionControllerProvider);
    var slots = await controller.getAvailability();
    if (!mounted) return;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .92,
          minChildSize: .65,
          maxChildSize: .96,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('When can you ride?',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text(
                            'Set your real time windows. CycleReady will choose sessions that fit them.'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final hour = slot.startMinutes ~/ 60;
                    final minute = slot.startMinutes % 60;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                                child: Text(_weekdays[index],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16))),
                            Switch(
                              value: slot.enabled,
                              onChanged: (value) => setSheetState(() {
                                slots[index] = slot.copyWith(enabled: value);
                              }),
                            ),
                          ]),
                          if (slot.enabled) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.schedule),
                                  label: Text(
                                      TimeOfDay(hour: hour, minute: minute)
                                          .format(context)),
                                  onPressed: () async {
                                    final value = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          TimeOfDay(hour: hour, minute: minute),
                                    );
                                    if (value != null) {
                                      setSheetState(() {
                                        slots[index] = slots[index].copyWith(
                                          startMinutes:
                                              value.hour * 60 + value.minute,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: slot.durationMinutes,
                                  decoration: const InputDecoration(
                                      labelText: 'Time available'),
                                  items: const [
                                    30,
                                    45,
                                    60,
                                    75,
                                    90,
                                    120,
                                    150,
                                    180,
                                    240
                                  ]
                                      .map((minutes) => DropdownMenuItem(
                                            value: minutes,
                                            child: Text(minutes < 60
                                                ? '$minutes min'
                                                : '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}'),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setSheetState(() {
                                        slots[index] = slots[index]
                                            .copyWith(durationMinutes: value);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            SegmentedButton<RideSetting>(
                              segments: const [
                                ButtonSegment(
                                    value: RideSetting.indoor,
                                    label: Text('Indoor'),
                                    icon: Icon(Icons.home_outlined)),
                                ButtonSegment(
                                    value: RideSetting.outdoor,
                                    label: Text('Outside'),
                                    icon: Icon(Icons.landscape_outlined)),
                                ButtonSegment(
                                    value: RideSetting.flexible,
                                    label: Text('Either')),
                              ],
                              selected: {slot.setting},
                              onSelectionChanged: (value) => setSheetState(() {
                                slots[index] =
                                    slots[index].copyWith(setting: value.first);
                              }),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: slots.any((slot) => slot.enabled)
                        ? () => Navigator.pop(context, true)
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Save and rebuild my plan'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    await controller.saveAvailability(slots);
    final count = await controller.generateAdaptivePlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Availability saved and $count workouts planned.')),
    );
  }

  Future<void> _publishToGarmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send workouts to Garmin?'),
        content: const Text(
          'CycleReady will publish your uncompleted cycling workouts for the '
          'next 14 days to your Intervals.icu calendar. Intervals can then '
          'deliver them to Garmin.\n\n'
          'Publishing again safely updates the same CycleReady workouts '
          'instead of creating duplicates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Send workouts'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await ref
          .read(plannedSessionControllerProvider)
          .publishUpcomingToIntervals();
      if (!mounted) return;
      final message = count == 0
          ? 'There are no uncompleted workouts to send in the next 14 days.'
          : 'Sent $count workout${count == 1 ? '' : 's'} to Intervals.icu. '
              'Garmin delivery is handled by your Intervals connection.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  static (int, int) _defaults(SessionType type) => switch (type) {
        SessionType.rest => (0, 0),
        SessionType.recovery => (30, 15),
        SessionType.endurance => (60, 40),
        SessionType.tempo => (60, 60),
        SessionType.intervals => (60, 75),
      };

  static String _fullDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text('${_months[month.month - 1]} ${month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ]);
}

class _WeeklyRideSummary extends StatelessWidget {
  const _WeeklyRideSummary({required this.rides});

  final List<Activity> rides;

  @override
  Widget build(BuildContext context) {
    final distance =
        rides.fold<double>(0, (sum, ride) => sum + ride.distanceMetres);
    final seconds =
        rides.fold<int>(0, (sum, ride) => sum + ride.durationSeconds);
    final load = rides.fold<int>(
      0,
      (sum, ride) => sum + (ride.trainingLoad ?? 0),
    );
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final time = hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This week',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    value: '${rides.length}',
                    label: 'RIDES',
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    value: Units.distance(distance, decimals: 0),
                    label: 'DISTANCE',
                  ),
                ),
                Expanded(
                  child: _SummaryValue(value: time, label: 'TIME'),
                ),
                Expanded(
                  child: _SummaryValue(value: '$load', label: 'LOAD'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 1)),
      ]);
}

class _WorkoutHeadlineMetric extends StatelessWidget {
  const _WorkoutHeadlineMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 5),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: 9, letterSpacing: .5)),
        ],
      );
}

class _PersonalTarget extends StatelessWidget {
  const _PersonalTarget({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.sessions,
    required this.completedDays,
    required this.strengthDays,
    required this.onSelected,
    required this.onLongPressEntry,
  });
  final DateTime month;
  final DateTime selectedDay;
  final Map<int, PlannedSession> sessions;
  final Set<int> completedDays;
  final Set<int> strengthDays;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onLongPressEntry;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday - 1;
    return Column(children: [
      Row(
        children: _weekdays
            .map((day) => Expanded(
                  child: Text(day.substring(0, 1),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: leading + days,
        itemBuilder: (context, index) {
          if (index < leading) return const SizedBox.shrink();
          final dayNumber = index - leading + 1;
          final date = DateTime(month.year, month.month, dayNumber);
          final session = sessions[dayNumber];
          final completed = completedDays.contains(dayNumber);
          final selected = date.year == selectedDay.year &&
              date.month == selectedDay.month &&
              date.day == selectedDay.day;
          final isToday = _sameDay(date, DateTime.now());
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(date),
            onLongPress: session == null && !strengthDays.contains(dayNumber)
                ? null
                : () => onLongPressEntry(date),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$dayNumber',
                        style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal)),
                    const SizedBox(height: 3),
                    if (session != null || completed)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed
                              ? const Color(0xFF19E56F)
                              : _typeColor(session!.sessionType),
                        ),
                      ),
                  ]),
            ),
          );
        },
      ),
    ]);
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(child: Icon(Icons.add)),
          title: const Text('No workout planned'),
          subtitle: const Text('Add a ride or make this a recovery day.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onAdd,
        ),
      );
}

class _CompletedDayCard extends StatelessWidget {
  const _CompletedDayCard({required this.rides, this.planned});
  final List<Activity> rides;
  final PlannedSession? planned;

  @override
  Widget build(BuildContext context) {
    final distance =
        rides.fold<double>(0, (sum, ride) => sum + ride.distanceMetres);
    final minutes =
        rides.fold<int>(0, (sum, ride) => sum + ride.durationSeconds) ~/ 60;
    final load =
        rides.fold<int>(0, (sum, ride) => sum + (ride.trainingLoad ?? 0));
    final loadCompletion = planned == null || planned!.targetLoad == 0
        ? null
        : load / planned!.targetLoad;
    final durationCompletion = planned == null || planned!.durationMinutes == 0
        ? null
        : minutes / planned!.durationMinutes;
    final compliance = planned == null
        ? null
        : assessWorkoutCompliance(
            plannedLoad: planned!.targetLoad,
            plannedMinutes: planned!.durationMinutes,
            actualLoad: load,
            actualMinutes: minutes,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x3319E56F),
                child: Icon(Icons.check, color: Color(0xFF19E56F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rides.length == 1
                          ? 'Completed ride'
                          : '${rides.length} completed rides',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${Units.distance(distance)} · $minutes min'
                      '${load > 0 ? ' · load $load' : ''}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rides.map(
            (ride) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_bike),
              title: Text(
                ride.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_rideSummary(ride)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/activities/${ride.id}'),
            ),
          ),
          if (planned != null) ...[
            const Divider(),
            if (compliance != null) ...[
              _ComplianceStatus(compliance: compliance),
              const SizedBox(height: 12),
            ],
            Text('Planned: ${planned!.title}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (loadCompletion != null)
              _ComplianceRow(
                label: 'Load',
                actual: load,
                planned: planned!.targetLoad,
                ratio: loadCompletion,
              ),
            if (durationCompletion != null)
              _ComplianceRow(
                label: 'Duration',
                actual: minutes,
                planned: planned!.durationMinutes,
                ratio: durationCompletion,
                suffix: ' min',
              ),
          ],
        ]),
      ),
    );
  }

  String _rideSummary(Activity ride) {
    final parts = <String>[
      Units.distance(ride.distanceMetres),
      '${ride.durationSeconds ~/ 3600}h '
          '${(ride.durationSeconds % 3600) ~/ 60}m',
      if (ride.trainingLoad != null) 'load ${ride.trainingLoad}',
      if (ride.averagePower != null) '${ride.averagePower} W avg',
      if (ride.normalisedPower != null) '${ride.normalisedPower} W NP',
      if (ride.averageHeartRate != null) '${ride.averageHeartRate} bpm',
    ];
    return parts.join(' · ');
  }
}

class _CompletedStrengthCard extends ConsumerWidget {
  const _CompletedStrengthCard({
    required this.session,
    required this.onDelete,
  });

  final StrengthSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobility = session.routineName.startsWith('Mobility ·');
    final sets = ref.watch(strengthSetsProvider(session.id)).valueOrNull ??
        const <StrengthSet>[];
    final completedSets = sets.where((set) => set.completed).toList();
    final exerciseIds = completedSets.map((set) => set.exerciseId).toSet();
    final exerciseNames = exerciseIds.map((id) {
      return strengthExercises
          .where((exercise) => exercise.id == id)
          .map((exercise) => exercise.name)
          .firstOrNull;
    }).whereType<String>();
    final volume = completedSets.fold<double>(
      0,
      (total, set) => total + set.weightKg * set.completedReps,
    );
    final completedAt = session.completedAt!;
    final minutes =
        completedAt.difference(session.startedAt).inMinutes.clamp(1, 999);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Color(0x3319E56F),
                child: Icon(
                  isMobility ? Icons.self_improvement : Icons.fitness_center,
                  color: const Color(0xFF19E56F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.routineName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Completed ${isMobility ? 'mobility' : 'strength'} session · $minutes min',
                    ),
                  ],
                ),
              ),
            ]),
            if (completedSets.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${exerciseIds.length} exercises · ${completedSets.length} sets'
                '${volume > 0 ? ' · ${volume.round()} kg volume' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (exerciseNames.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(exerciseNames.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _ComplianceRow extends StatelessWidget {
  const _ComplianceRow({
    required this.label,
    required this.actual,
    required this.planned,
    required this.ratio,
    this.suffix = '',
  });
  final String label;
  final int actual;
  final int planned;
  final double ratio;
  final String suffix;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('$actual$suffix / $planned$suffix'),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio.clamp(0, 1.25) / 1.25,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: ratio >= .8 && ratio <= 1.2
                ? const Color(0xFF19E56F)
                : Theme.of(context).colorScheme.tertiary,
          ),
        ]),
      );
}

class _ComplianceStatus extends StatelessWidget {
  const _ComplianceStatus({required this.compliance});
  final WorkoutCompliance compliance;

  @override
  Widget build(BuildContext context) {
    final color = switch (compliance.outcome) {
      PlannedWorkoutOutcome.onTarget => const Color(0xFF19E56F),
      PlannedWorkoutOutcome.underTarget => const Color(0xFFFFC94D),
      PlannedWorkoutOutcome.overTarget => Theme.of(context).colorScheme.error,
      PlannedWorkoutOutcome.missed => Theme.of(context).colorScheme.outline,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        border: Border.all(color: color.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights, color: color, size: 19),
          const SizedBox(width: 8),
          Text(compliance.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 5),
        Text(compliance.explanation),
      ]),
    );
  }
}

class _PlannedDayCard extends StatelessWidget {
  const _PlannedDayCard({
    required this.session,
    required this.onDelete,
  });
  final PlannedSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor:
                    _typeColor(session.sessionType).withValues(alpha: .2),
                child: Icon(
                  session.sessionType == SessionType.rest.name
                      ? Icons.self_improvement
                      : Icons.directions_bike,
                  color: _typeColor(session.sessionType),
                ),
              ),
              title: Text(session.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(session.durationMinutes == 0
                  ? 'Recovery day'
                  : '${session.durationMinutes} minutes · load ${session.targetLoad}'
                      '${session.prescription.isEmpty ? '' : '\n${session.prescription}'}'),
            ),
            if (session.adaptationReason.isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        session.adaptationReason,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove from calendar'),
              ),
            ),
          ]),
        ),
      );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.valueLabel,
    required this.value,
    this.min = 0,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ]);
}

String _typeLabel(SessionType type) => switch (type) {
      SessionType.rest => 'Rest day',
      SessionType.recovery => 'Recovery ride',
      SessionType.endurance => 'Endurance ride',
      SessionType.tempo => 'Tempo intervals',
      SessionType.intervals => 'Hard intervals',
    };

String _goalLabel(TrainingGoal goal) => switch (goal) {
      TrainingGoal.generalFitness => 'General cycling fitness',
      TrainingGoal.ftp => 'Improve FTP',
      TrainingGoal.endurance => 'Build endurance',
      TrainingGoal.event => 'Prepare for an event',
    };

Color _typeColor(String type) => switch (type) {
      'rest' => const Color(0xFF8CB9D0),
      'recovery' => const Color(0xFF72D7C1),
      'endurance' => const Color(0xFF16A7E8),
      'tempo' => const Color(0xFFFFB020),
      'intervals' => const Color(0xFFFF6B6B),
      _ => const Color(0xFF72D7C1),
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
