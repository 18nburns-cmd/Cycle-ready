import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StrengthScreen extends ConsumerWidget {
  const StrengthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(strengthProfileProvider).valueOrNull;
    final sessions =
        ref.watch(strengthSessionsProvider).valueOrNull ?? const [];
    final progressions =
        ref.watch(strengthProgressionsProvider).valueOrNull ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strength',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Mobility and stretching',
            onPressed: () => context.push('/strength/mobility'),
            icon: const Icon(Icons.self_improvement),
          ),
          IconButton(
            tooltip: 'Strength setup',
            onPressed: () => _showSetup(context, ref, profile),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: profile == null
          ? _StrengthWelcome(onSetup: () => _showSetup(context, ref, null))
          : _StrengthPlan(
              profile: profile,
              sessions: sessions,
              progressions: progressions,
            ),
    );
  }

  Future<void> _showSetup(
    BuildContext context,
    WidgetRef ref,
    StrengthProfile? existing,
  ) async {
    var goal = StrengthGoal.values.firstWhere(
      (value) => value.name == existing?.goal,
      orElse: () => StrengthGoal.cyclingPerformance,
    );
    var location = TrainingLocation.values.firstWhere(
      (value) => value.name == existing?.location,
      orElse: () => TrainingLocation.home,
    );
    var experience = StrengthExperience.values.firstWhere(
      (value) => value.name == existing?.experience,
      orElse: () => StrengthExperience.beginner,
    );
    var days = existing?.daysPerWeek ?? 2;
    var minutes = existing?.sessionMinutes ?? 45;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Build your strength plan',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                  initialValue: goal,
                  decoration: const InputDecoration(labelText: 'Main goal'),
                  items: StrengthGoal.values
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(_goal(value))))
                      .toList(),
                  onChanged: (value) => setState(() => goal = value!)),
              const SizedBox(height: 12),
              SegmentedButton<TrainingLocation>(
                  segments: const [
                    ButtonSegment(
                        value: TrainingLocation.home,
                        label: Text('Home'),
                        icon: Icon(Icons.home_outlined)),
                    ButtonSegment(
                        value: TrainingLocation.gym,
                        label: Text('Gym'),
                        icon: Icon(Icons.fitness_center))
                  ],
                  selected: {
                    location
                  },
                  onSelectionChanged: (value) =>
                      setState(() => location = value.first)),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                  initialValue: experience,
                  decoration: const InputDecoration(labelText: 'Experience'),
                  items: StrengthExperience.values
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(_experience(value))))
                      .toList(),
                  onChanged: (value) => setState(() => experience = value!)),
              const SizedBox(height: 12),
              _ChoiceSlider(
                  label: 'Sessions each week',
                  value: days,
                  min: 1,
                  max: 4,
                  suffix: '',
                  onChanged: (value) => setState(() => days = value)),
              _ChoiceSlider(
                  label: 'Session length',
                  value: minutes,
                  min: 20,
                  max: 75,
                  divisions: 11,
                  suffix: ' min',
                  onChanged: (value) => setState(() => minutes = value)),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Build my routine'))),
            ]),
          ),
        ),
      ),
    );
    if (saved != true) return;
    await ref.read(strengthControllerProvider).saveProfile(
          goal: goal.name,
          location: location.name,
          experience: experience.name,
          daysPerWeek: days,
          sessionMinutes: minutes,
          equipment: location == TrainingLocation.gym
              ? ['gym']
              : ['bodyweight', 'dumbbells'],
        );
  }
}

class _StrengthWelcome extends StatelessWidget {
  const _StrengthWelcome({required this.onSetup});
  final VoidCallback onSetup;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fitness_center, size: 70),
            const SizedBox(height: 18),
            Text('Strength that supports your riding',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
                'Choose your goal, equipment and available time. CycleReady will create guided sessions and track every set.',
                textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton.icon(
                onPressed: onSetup,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Create strength plan')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: () => context.push('/strength/mobility'),
                icon: const Icon(Icons.self_improvement),
                label: const Text('Mobility & stretching'))
          ])));
}

class _StrengthPlan extends StatelessWidget {
  const _StrengthPlan({
    required this.profile,
    required this.sessions,
    required this.progressions,
  });
  final StrengthProfile profile;
  final List<StrengthSession> sessions;
  final Map<String, StrengthProgression> progressions;
  @override
  Widget build(BuildContext context) {
    final program = buildStrengthProgram(
        goal: StrengthGoal.values.byName(profile.goal),
        location: TrainingLocation.values.byName(profile.location),
        experience: StrengthExperience.values.byName(profile.experience),
        daysPerWeek: profile.daysPerWeek);
    final completed =
        sessions.where((value) => value.completedAt != null).length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.track_changes, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_goal(StrengthGoal.values.byName(profile.goal)),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                              '${profile.daysPerWeek} sessions/week · ${profile.sessionMinutes} min · ${profile.location == 'gym' ? 'Gym' : 'Home'}')
                        ])),
                    Text('$completed done',
                        style: const TextStyle(fontWeight: FontWeight.w800))
                  ]))),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: .55),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                child: Icon(Icons.playlist_add),
              ),
              title: const Text(
                'Build your own workout',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Choose Back, Arms, Legs, Chest & Shoulders, Core or Full Body',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/strength/custom'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: .6),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                child: Icon(Icons.self_improvement),
              ),
              title: const Text(
                'Mobility & stretching',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Guided pre-ride, post-ride and daily cyclist routines',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/strength/mobility'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Your routine',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          ...program.asMap().entries.map((entry) => Card(
              child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(entry.value.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${entry.value.focus}\n${entry.value.exercises.length} exercises'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.play_circle_fill),
                  onTap: () =>
                      context.push('/strength/workout/${entry.key}')))),
          if (progressions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Next-session progression',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            ...progressions.values.take(6).map((progression) {
              final exercise = strengthExercises.firstWhere(
                (value) => value.id == progression.exerciseId,
              );
              final increasing =
                  progression.action == ProgressionAction.increase ||
                      progression.action == ProgressionAction.addReps;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (increasing
                            ? const Color(0xFF19E56F)
                            : Theme.of(context).colorScheme.tertiary)
                        .withValues(alpha: .18),
                    child: Icon(
                      increasing ? Icons.trending_up : Icons.replay,
                      color: increasing
                          ? const Color(0xFF19E56F)
                          : Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  title: Text(exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(progression.message),
                  trailing: progression.bestWeightKg > 0
                      ? Text(
                          'PB\n${progression.bestWeightKg.toStringAsFixed(1)} kg',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        )
                      : null,
                ),
              );
            }),
          ],
          const SizedBox(height: 18),
          Text('Workout history',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (sessions.where((value) => value.completedAt != null).isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                        'Complete your first routine to begin tracking strength progress.')))
          else
            ...sessions.where((value) => value.completedAt != null).take(8).map(
                (value) => Card(
                    child: ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: Color(0xFF19E56F)),
                        title: Text(value.routineName),
                        subtitle: Text(
                            '${value.completedAt!.day}/${value.completedAt!.month}/${value.completedAt!.year}')))),
        ]);
  }
}

class _ChoiceSlider extends StatelessWidget {
  const _ChoiceSlider(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.suffix,
      required this.onChanged,
      this.divisions});
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
              style: const TextStyle(fontWeight: FontWeight.w800))
        ]),
        Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? max - min,
            onChanged: (value) => onChanged(value.round()))
      ]);
}

String _goal(StrengthGoal goal) => switch (goal) {
      StrengthGoal.cyclingPerformance => 'Cycling performance',
      StrengthGoal.generalStrength => 'General strength',
      StrengthGoal.muscleGain => 'Build muscle',
      StrengthGoal.mobility => 'Mobility & resilience'
    };
String _experience(StrengthExperience value) => switch (value) {
      StrengthExperience.beginner => 'Beginner',
      StrengthExperience.intermediate => 'Intermediate',
      StrengthExperience.experienced => 'Experienced'
    };
