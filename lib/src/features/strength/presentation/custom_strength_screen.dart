import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/custom_strength_workout.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomStrengthScreen extends ConsumerStatefulWidget {
  const CustomStrengthScreen({super.key});

  @override
  ConsumerState<CustomStrengthScreen> createState() =>
      _CustomStrengthScreenState();
}

class _CustomStrengthScreenState extends ConsumerState<CustomStrengthScreen> {
  MuscleFocus focus = MuscleFocus.fullBody;
  final selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(strengthProfileProvider).valueOrNull;
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Complete strength setup first.')),
      );
    }
    final location = TrainingLocation.values.byName(profile.location);
    final exercises = exercisesForFocus(focus, location: location);
    final selected = strengthExercises
        .where((exercise) => selectedIds.contains(exercise.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose exercises',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: selected.isEmpty
                ? null
                : () => context.push(
                      '/strength/custom/workout',
                      extra: StrengthRoutine(
                        name: 'Custom · ${muscleFocusLabel(focus)}',
                        focus:
                            '${selected.length} selected exercises · ${profile.location == 'gym' ? 'Gym' : 'Home'}',
                        exercises: selected,
                      ),
                    ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              selected.isEmpty
                  ? 'Select at least one exercise'
                  : 'Start workout · ${selected.length} selected',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'What do you want to train?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MuscleFocus.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(muscleFocusLabel(value)),
                    selected: focus == value,
                    onSelected: (_) => setState(() => focus = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${muscleFocusLabel(focus)} exercises',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final visibleIds = exercises.map((item) => item.id).toSet();
                  if (visibleIds.every(selectedIds.contains)) {
                    selectedIds.removeAll(visibleIds);
                  } else {
                    selectedIds.addAll(visibleIds);
                  }
                }),
                child: const Text('Select all'),
              ),
            ],
          ),
          ...exercises.map(
            (exercise) => Card(
              child: CheckboxListTile(
                value: selectedIds.contains(exercise.id),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    selectedIds.add(exercise.id);
                  } else {
                    selectedIds.remove(exercise.id);
                  }
                }),
                secondary: const CircleAvatar(
                  child: Icon(Icons.fitness_center),
                ),
                title: Text(exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${exercise.muscles}\n${exercise.defaultSets} sets · ${exercise.defaultReps} reps',
                ),
                isThreeLine: true,
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${selected.length} selected across all groups. Switch categories to add more.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
