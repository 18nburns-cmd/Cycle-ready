import 'package:cycle_ready/src/features/coaching/application/workout_browser_controller.dart';
import 'package:flutter/material.dart';

class WorkoutBrowserFilters extends StatelessWidget {
  const WorkoutBrowserFilters({
    required this.state,
    required this.onFamilyChanged,
    required this.onDurationChanged,
    super.key,
  });

  final WorkoutBrowserState state;
  final ValueChanged<String?> onFamilyChanged;
  final ValueChanged<WorkoutBrowserDuration> onDurationChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            key: const Key('workout-family-filter'),
            initialValue: state.family,
            decoration: const InputDecoration(labelText: 'Workout family'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All families')),
              ...([...state.families]..sort()).map(
                (family) => DropdownMenuItem<String?>(
                  value: family,
                  child: Text(family),
                ),
              ),
            ],
            onChanged: onFamilyChanged,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<WorkoutBrowserDuration>(
              key: const Key('workout-duration-filter'),
              segments: const [
                ButtonSegment(
                  value: WorkoutBrowserDuration.any,
                  label: Text('Any length'),
                ),
                ButtonSegment(
                  value: WorkoutBrowserDuration.upTo45Minutes,
                  label: Text('Up to 45 min'),
                ),
                ButtonSegment(
                  value: WorkoutBrowserDuration.from46To75Minutes,
                  label: Text('46â€“75 min'),
                ),
                ButtonSegment(
                  value: WorkoutBrowserDuration.over75Minutes,
                  label: Text('Over 75 min'),
                ),
              ],
              selected: {state.duration},
              onSelectionChanged: (selection) =>
                  onDurationChanged(selection.single),
            ),
          ),
        ],
      );
}
