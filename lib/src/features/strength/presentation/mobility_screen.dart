import 'package:cycle_ready/src/features/strength/domain/mobility_program.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobilityScreen extends StatelessWidget {
  const MobilityScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mobility & Stretching',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.self_improvement, size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Move better on the bike and restore the positions cycling holds for long periods. Stretching should feel like controlled tension—never sharp pain.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...mobilityRoutines.asMap().entries.map(
                  (entry) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        child: Icon(_purposeIcon(entry.value.purpose)),
                      ),
                      title: Text(
                        entry.value.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${entry.value.description}\n${entry.value.minutes} min · ${entry.value.exercises.length} movements',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.play_circle_fill),
                      onTap: () =>
                          context.push('/strength/mobility/${entry.key}'),
                    ),
                  ),
                ),
          ],
        ),
      );

  static IconData _purposeIcon(MobilityPurpose purpose) => switch (purpose) {
        MobilityPurpose.preRide => Icons.directions_bike,
        MobilityPurpose.postRide => Icons.bedtime_outlined,
        MobilityPurpose.daily => Icons.accessibility_new,
      };
}
