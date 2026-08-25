import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  double fatigue = 3;
  double soreness = 3;
  double stress = 3;
  double motivation = 3;
  bool initialized = false;
  bool savedThisVisit = false;

  @override
  Widget build(BuildContext context) {
    final recovery = ref.watch(recoveryControllerProvider);
    final savedToday =
        ref.watch(todayCheckInCompletedProvider).valueOrNull ?? false;
    final locked = savedToday || savedThisVisit;
    if (!initialized && recovery.valueOrNull != null) {
      final value = recovery.valueOrNull!;
      fatigue = value.fatigue.toDouble();
      soreness = value.soreness.toDouble();
      stress = value.stress.toDouble();
      motivation = value.motivation.toDouble();
      initialized = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Morning check-in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('How do you feel today?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Use 1 for very low and 5 for very high. Your answers stay on this phone.'),
          if (locked) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: .5),
              child: const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text(
                  'Today’s check-in is complete',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Your answers are locked until tomorrow so today’s readiness stays consistent.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Scale(
              label: 'Fatigue',
              low: 'Fresh',
              high: 'Exhausted',
              value: fatigue,
              onChanged: locked ? null : (v) => setState(() => fatigue = v)),
          _Scale(
              label: 'Leg soreness',
              low: 'None',
              high: 'Severe',
              value: soreness,
              onChanged: locked ? null : (v) => setState(() => soreness = v)),
          _Scale(
              label: 'Stress',
              low: 'Calm',
              high: 'Very stressed',
              value: stress,
              onChanged: locked ? null : (v) => setState(() => stress = v)),
          _Scale(
              label: 'Motivation',
              low: 'Very low',
              high: 'Very high',
              value: motivation,
              onChanged: locked ? null : (v) => setState(() => motivation = v)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: recovery.isLoading || locked ? null : _save,
            icon: Icon(locked ? Icons.lock : Icons.check),
            label: Text(
                locked ? 'Check-in saved for today' : 'Save today’s check-in'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final saved =
        await ref.read(recoveryControllerProvider.notifier).saveCheckIn(
              fatigue: fatigue.round(),
              soreness: soreness.round(),
              stress: stress.round(),
              motivation: motivation.round(),
            );
    if (mounted) {
      setState(() => savedThisVisit = savedThisVisit || saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? 'Today’s check-in was saved.'
              : 'Today’s check-in was already completed.'),
        ),
      );
    }
  }
}

class DailyCheckInPrompt extends ConsumerStatefulWidget {
  const DailyCheckInPrompt({super.key});

  @override
  ConsumerState<DailyCheckInPrompt> createState() => _DailyCheckInPromptState();
}

class _DailyCheckInPromptState extends ConsumerState<DailyCheckInPrompt> {
  double fatigue = 3;
  double soreness = 3;
  double stress = 3;
  double motivation = 3;
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    await ref.read(recoveryControllerProvider.notifier).saveCheckIn(
          fatigue: fatigue.round(),
          soreness: soreness.round(),
          stress: stress.round(),
          motivation: motivation.round(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.fact_check_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Complete today’s check-in to calculate readiness.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Scale(
                label: 'Fatigue',
                low: 'Fresh',
                high: 'Exhausted',
                value: fatigue,
                onChanged: (value) => setState(() => fatigue = value),
              ),
              _Scale(
                label: 'Leg soreness',
                low: 'None',
                high: 'Severe',
                value: soreness,
                onChanged: (value) => setState(() => soreness = value),
              ),
              _Scale(
                label: 'Stress',
                low: 'Calm',
                high: 'Very stressed',
                value: stress,
                onChanged: (value) => setState(() => stress = value),
              ),
              _Scale(
                label: 'Motivation',
                low: 'Very low',
                high: 'Very high',
                value: motivation,
                onChanged: (value) => setState(() => motivation = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(saving ? 'Saving…' : 'Save today’s check-in'),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Your answers are stored on this phone and lock until tomorrow.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Scale extends StatelessWidget {
  const _Scale(
      {required this.label,
      required this.low,
      required this.high,
      required this.value,
      this.onChanged});
  final String label;
  final String low;
  final String high;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.titleMedium)),
              CircleAvatar(child: Text('${value.round()}'))
            ]),
            Slider(
                value: value,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: onChanged),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(low), Text(high)]),
          ]),
        ),
      );
}
