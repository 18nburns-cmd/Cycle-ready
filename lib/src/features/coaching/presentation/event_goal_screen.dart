import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/coaching/application/event_goal_controller.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/event_periodisation.dart';
import 'package:cycle_ready/src/features/coaching/domain/coaching_event_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventGoalScreen extends ConsumerWidget {
  const EventGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventGoalProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Goal Event',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit event',
            onPressed: () => _editEvent(context, ref, event.valueOrNull),
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
        ],
      ),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Event could not be loaded.')),
        data: (value) => value == null
            ? _EmptyEvent(onCreate: () => _editEvent(context, ref, null))
            : _EventPlan(event: value),
      ),
    );
  }

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref,
    CoachingEventGoal? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final distance = TextEditingController(
      text: existing == null ? '' : existing.distanceKm.toStringAsFixed(0),
    );
    final elevation = TextEditingController(
      text: existing?.elevationMetres.toString() ?? '',
    );
    var date =
        existing?.eventDate ?? DateTime.now().add(const Duration(days: 84));
    var priority = existing?.priority ?? 'A';
    var target = existing?.target ?? 'finishStrong';
    var terrain = existing?.terrain ?? 'rolling';
    var days = existing?.availableDays ?? 4;
    var longRide = existing?.longRideMinutes ?? 180;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Create goal event' : 'Edit goal event',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Event name'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Event date'),
                  subtitle: Text(_date(date)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: distance,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Distance · km'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: elevation,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Elevation · m'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: terrain,
                  decoration: const InputDecoration(labelText: 'Terrain'),
                  items: const [
                    DropdownMenuItem(value: 'flat', child: Text('Flat')),
                    DropdownMenuItem(value: 'rolling', child: Text('Rolling')),
                    DropdownMenuItem(
                        value: 'mountainous', child: Text('Mountainous')),
                    DropdownMenuItem(
                        value: 'mixed', child: Text('Mixed / off-road')),
                  ],
                  onChanged: (value) => setState(() => terrain = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: 'Target'),
                  items: const [
                    DropdownMenuItem(
                        value: 'finishStrong', child: Text('Finish strong')),
                    DropdownMenuItem(
                        value: 'targetTime', child: Text('Target a time')),
                    DropdownMenuItem(
                        value: 'race', child: Text('Race competitively')),
                  ],
                  onChanged: (value) => setState(() => target = value!),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'A', label: Text('A priority')),
                    ButtonSegment(value: 'B', label: Text('B priority')),
                    ButtonSegment(value: 'C', label: Text('C priority')),
                  ],
                  selected: {priority},
                  onSelectionChanged: (value) =>
                      setState(() => priority = value.first),
                ),
                const SizedBox(height: 14),
                _EventSlider(
                  label: 'Training days each week',
                  value: days,
                  min: 2,
                  max: 6,
                  suffix: ' days',
                  onChanged: (value) => setState(() => days = value),
                ),
                _EventSlider(
                  label: 'Longest available ride',
                  value: longRide,
                  min: 60,
                  max: 360,
                  divisions: 10,
                  suffix: ' min',
                  onChanged: (value) => setState(() => longRide = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.flag),
                    label: const Text('Save event and build phases'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    final parsedDistance = double.tryParse(distance.text);
    final parsedElevation = int.tryParse(elevation.text);
    if (name.text.trim().isEmpty ||
        parsedDistance == null ||
        parsedDistance <= 0 ||
        parsedElevation == null ||
        parsedElevation < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter a valid name, distance and elevation.')),
        );
      }
      return;
    }
    await ref.read(eventGoalControllerProvider).save(
          name: name.text,
          eventDate: date,
          distanceKm: parsedDistance,
          elevationMetres: parsedElevation,
          priority: priority,
          target: target,
          terrain: terrain,
          availableDays: days,
          longRideMinutes: longRide,
        );
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class _EmptyEvent extends StatelessWidget {
  const _EmptyEvent({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_circle_outlined, size: 72),
              const SizedBox(height: 16),
              Text(
                'Train toward something meaningful',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Add a sportive, race or personal challenge. CycleReady will periodise training and taper you toward the date.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create goal event'),
              ),
            ],
          ),
        ),
      );
}

class _EventPlan extends ConsumerWidget {
  const _EventPlan({required this.event});
  final CoachingEventGoal event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final days = event.eventDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final phase = eventPhaseFor(now, event.eventDate);
    final blocks = buildEventBlocks(now: now, eventDate: event.eventDate);
    final estimatedHours = event.distanceKm /
        (event.terrain == 'mountainous'
            ? 20
            : event.terrain == 'flat'
                ? 28
                : 24);
    final carbs = estimatedHours >= 3 ? '75–90 g' : '60–75 g';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.flag, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(event.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ),
                  Text('${event.priority} EVENT',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                Text(
                  '${days.clamp(0, 999)} days · ${Units.distance(event.distanceKm * 1000)} · ${Units.elevation(event.elevationMetres.toDouble())}',
                ),
                const SizedBox(height: 8),
                Chip(label: Text('Current phase · ${eventPhaseLabel(phase)}')),
                const SizedBox(height: 6),
                Text(eventPhaseFocus(phase)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () async {
            final count = await ref
                .read(plannedSessionControllerProvider)
                .generateAdaptivePlan();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Built $count event-focused sessions.')),
              );
            }
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Build four-week event block'),
        ),
        const SizedBox(height: 18),
        Text('Training phases',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        ...blocks.map((block) => Card(
              child: ListTile(
                leading:
                    CircleAvatar(child: Text('${blocks.indexOf(block) + 1}')),
                title: Text(eventPhaseLabel(block.phase),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${_shortDate(block.start)}–${_shortDate(block.end)} · ${block.loadDirection}\n${block.focus}'),
                isThreeLine: true,
              ),
            )),
        const SizedBox(height: 16),
        Text('Event-day starting plan',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Estimated riding time: ${estimatedHours.toStringAsFixed(1)} hours. Start conservatively, keep the opening hour below threshold, target $carbs carbohydrate each hour and roughly 500–750 ml fluid per hour, adjusted for temperature and sweat rate. Rehearse this during event-specific long rides.',
            ),
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime value) => '${value.day}/${value.month}';
}

class _EventSlider extends StatelessWidget {
  const _EventSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.divisions,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final int? divisions;
  final String suffix;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('$value$suffix',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions ?? max - min,
          onChanged: (value) => onChanged(value.round()),
        ),
      ]);
}
