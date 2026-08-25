import 'package:cycle_ready/src/features/coaching/application/offline_coach_provider.dart';
import 'package:cycle_ready/src/features/coaching/application/coach_reminder_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/offline_coach.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OfflineCoachScreen extends ConsumerWidget {
  const OfflineCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(offlineCoachReportProvider);
    final reminder = ref.watch(coachReminderControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final accent = switch (report.tone) {
      CoachTone.celebrate => const Color(0xFF19D879),
      CoachTone.steady => const Color(0xFF45B6FE),
      CoachTone.recover => const Color(0xFFFFB74D),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: .65),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.psychology)),
              title: const Text('AI Coach',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                'Optional local AI explanations · private and free to use',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/ai'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: accent.withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'TODAY’S COACHING',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    report.headline,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(report.message),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: reminder.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const ListTile(
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('Evening reminder unavailable'),
                subtitle: Text('Restart the app and try again.'),
              ),
              data: (settings) => Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Evening coaching reminder',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Every day at ${settings.formattedTime}'),
                    value: settings.enabled,
                    onChanged: (value) async {
                      final allowed = await ref
                          .read(coachReminderControllerProvider.notifier)
                          .setEnabled(value);
                      if (value && !allowed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Allow notifications to enable the reminder.'),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    enabled: settings.enabled,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Reminder time'),
                    trailing: Text(settings.formattedTime),
                    onTap: settings.enabled
                        ? () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: settings.hour,
                                minute: settings.minute,
                              ),
                            );
                            if (picked != null) {
                              await ref
                                  .read(
                                      coachReminderControllerProvider.notifier)
                                  .setTime(picked.hour, picked.minute);
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _CoachSection(
            icon: Icons.emoji_events_outlined,
            title: 'What went well',
            items: report.wins,
            color: const Color(0xFF19D879),
          ),
          _CoachSection(
            icon: Icons.adjust,
            title: 'What needs attention',
            items: report.focus,
            color: const Color(0xFFFFB74D),
          ),
          _CoachSection(
            icon: Icons.bedtime_outlined,
            title: 'Do this tonight',
            items: report.tonight,
            color: const Color(0xFF8CB9D0),
          ),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading:
                  Icon(Icons.directions_bike_outlined, color: colors.primary),
              title: const Text('Tomorrow',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(report.tomorrow),
              ),
            ),
          ),
          if (report.dataNotes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Data confidence',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...report.dataNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Generated entirely on this phone. No health data is sent to an AI service. Advice supports training decisions and is not medical advice.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CoachSection extends StatelessWidget {
  const _CoachSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: color, fontSize: 18)),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
