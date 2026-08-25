import 'package:cycle_ready/src/features/coaching/application/local_ai_coach_provider.dart';
import 'package:cycle_ready/src/features/coaching/application/local_ai_model_manager.dart';
import 'package:cycle_ready/src/features/coaching/application/local_ai_coach_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalAiCoachScreen extends ConsumerStatefulWidget {
  const LocalAiCoachScreen({super.key});

  @override
  ConsumerState<LocalAiCoachScreen> createState() => _LocalAiCoachScreenState();
}

class _LocalAiCoachScreenState extends ConsumerState<LocalAiCoachScreen> {
  final question = TextEditingController();

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(localAiModelManagerProvider);
    final coach = ref.watch(localAiCoachControllerProvider);
    final dataset = ref.watch(localCoachDatasetProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (model.installed)
            IconButton(
              tooltip: 'Delete local model',
              onPressed: _deleteModel,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Icon(Icons.phonelink_lock, size: 34),
              title: Text('Private, on-device AI',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                'AI analysis is performed on this device. Your health and cycling data is not sent to an AI server.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!model.installed) _ModelSetupCard(model: model),
          if (model.installed) ...[
            _ReadinessSummary(dataset: dataset),
            const SizedBox(height: 12),
            Text('Choose an analysis',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LocalCoachTask.values
                  .map(
                    (task) => ChoiceChip(
                      label: Text(localCoachTaskLabel(task)),
                      selected: coach.task == task,
                      onSelected: coach.generating
                          ? null
                          : (_) => ref
                              .read(localAiCoachControllerProvider.notifier)
                              .selectTask(task),
                    ),
                  )
                  .toList(),
            ),
            if (coach.task == LocalCoachTask.askCoach) ...[
              const SizedBox(height: 14),
              TextField(
                controller: question,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ask about your training data',
                  hintText: 'Why is my readiness low?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  'Should I ride today?',
                  'How is my fitness changing?',
                  'Am I training too hard?',
                ]
                    .map((text) => ActionChip(
                          label: Text(text),
                          onPressed: () => question.text = text,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            if (coach.generating)
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(localAiCoachControllerProvider.notifier).cancel(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop generation'),
              )
            else
              FilledButton.icon(
                onPressed: coach.task == LocalCoachTask.latestRide &&
                        dataset.metrics.latestRide == null
                    ? null
                    : () => ref
                        .read(localAiCoachControllerProvider.notifier)
                        .generate(
                          question: coach.task == LocalCoachTask.askCoach
                              ? question.text.trim()
                              : null,
                        ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(localCoachTaskLabel(coach.task)),
              ),
            if (coach.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(coach.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (coach.generating)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Your coach is looking over your training…'),
                ]),
              ),
            if (coach.response != null)
              _CoachResponseCard(response: coach.response!),
          ],
          const SizedBox(height: 18),
          Text(
            'CycleReady calculates readiness, FTP, training load and recovery before AI is used. The model only explains supplied values and cannot alter your stored health data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local AI model?'),
        content: const Text(
          'This frees about 469 MB. Your cycling and health data will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localAiCoachServiceProvider).unload();
    await ref.read(localAiModelManagerProvider.notifier).deleteModel();
  }
}

class _ModelSetupCard extends ConsumerWidget {
  const _ModelSetupCard({required this.model});
  final LocalAiModelState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Install the local coach model',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${defaultLocalAiModel.name} · 469 MB download · no subscription or usage fees',
            ),
            const SizedBox(height: 10),
            if (model.downloading) ...[
              LinearProgressIndicator(value: model.progress),
              const SizedBox(height: 6),
              Text('${(model.progress * 100).toStringAsFixed(0)}% downloaded'),
              TextButton.icon(
                onPressed: () => ref
                    .read(localAiModelManagerProvider.notifier)
                    .cancelDownload(),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ] else
              FilledButton.icon(
                onPressed: () => _confirmDownload(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Download model'),
              ),
            if (model.error != null)
              Text(model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      );

  Future<void> _confirmDownload(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download 469 MB model?'),
        content: const Text(
          'The model is downloaded from the official Qwen repository and verified before use. Wi-Fi is recommended. It will be stored privately by CycleReady.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(localAiModelManagerProvider.notifier).download();
    }
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({required this.dataset});
  final LocalCoachDataset dataset;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(child: Text('${dataset.readiness.score}')),
          title: Text("Today's readiness · ${dataset.readiness.status}",
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${dataset.recommendation.name.toUpperCase()} · ${dataset.recoveryHours}h recovery',
          ),
        ),
      );
}

class _CoachResponseCard extends StatelessWidget {
  const _CoachResponseCard({required this.response});
  final LocalCoachResponse response;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CircleAvatar(child: Icon(Icons.psychology)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(response.headline,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(response.summary),
            if (response.keyFactors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("What I'm noticing",
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...response.keyFactors.map((factor) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $factor'),
                  )),
            ],
            const Divider(height: 24),
            const Text('My advice',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(response.recommendation,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (response.confidence == 'low' ||
                response.confidence == 'unstructured') ...[
              const SizedBox(height: 8),
              Text('Limited data confidence',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ]),
        ),
      );
}
