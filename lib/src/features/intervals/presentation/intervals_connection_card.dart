import 'package:cycle_ready/src/features/intervals/data/intervals_icu_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/activities/application/activity_import_controller.dart';
import 'package:cycle_ready/src/features/intervals/application/intervals_wellness_controller.dart';

class IntervalsConnectionCard extends ConsumerStatefulWidget {
  const IntervalsConnectionCard({super.key});
  @override
  ConsumerState<IntervalsConnectionCard> createState() =>
      _IntervalsConnectionCardState();
}

class _IntervalsConnectionCardState
    extends ConsumerState<IntervalsConnectionCard> {
  final athlete = TextEditingController();
  final apiKey = TextEditingController();
  bool loading = true;
  bool connected = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final credentials =
        await ref.read(intervalsIcuServiceProvider).credentials();
    if (!mounted) return;
    setState(() {
      if (credentials != null) athlete.text = credentials.athleteId;
      connected = credentials != null;
      loading = false;
    });
  }

  Future<void> _connect() async {
    if (athlete.text.trim().isEmpty || apiKey.text.trim().isEmpty) {
      setState(() => message = 'Enter both your Athlete ID and API key.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final value = IntervalsCredentials(athlete.text, apiKey.text);
      final valid =
          await ref.read(intervalsIcuServiceProvider).testConnection(value);
      if (valid) {
        await ref.read(intervalsIcuServiceProvider).saveCredentials(value);
        final imported = await ref
            .read(activityImportControllerProvider.notifier)
            .syncIntervals();
        ref.invalidate(intervalsWellnessAutoSyncProvider);
        apiKey.clear();
        message = _syncMessage('Connected.', imported);
      }
      if (!mounted) return;
      setState(() {
        connected = valid;
        message = valid ? message : 'Intervals.icu rejected those details.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Could not reach Intervals.icu. Check your internet connection.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() => loading = true);
    try {
      final imported = await ref
          .read(activityImportControllerProvider.notifier)
          .syncIntervals();
      ref.invalidate(intervalsWellnessAutoSyncProvider);
      if (mounted) {
        setState(() => message = _syncMessage('Sync complete.', imported));
      }
    } catch (error) {
      if (mounted) setState(() => message = 'Sync failed: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _syncMessage(String prefix, int imported) {
    final restricted =
        ref.read(intervalsIcuServiceProvider).lastRestrictedActivityCount;
    final result =
        '$prefix Imported $imported new ride${imported == 1 ? '' : 's'}.';
    if (restricted == 0) return result;
    return '$result $restricted Strava-sourced '
        'activit${restricted == 1 ? 'y is' : 'ies are'} unavailable through '
        'the Intervals.icu API. Connect Garmin directly to Intervals or '
        'import the FIT file.';
  }

  Future<void> _disconnect() async {
    await ref.read(intervalsIcuServiceProvider).disconnect();
    athlete.clear();
    apiKey.clear();
    setState(() {
      connected = false;
      message = 'Intervals.icu credentials removed from this phone.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final wellness = ref.watch(intervalsWellnessAutoSyncProvider).valueOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.query_stats)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Intervals.icu',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Activities, fitness and wellness'),
                  ]),
            ),
            Chip(label: Text(connected ? 'Connected' : 'Not connected')),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: athlete,
            enabled: !loading,
            decoration: const InputDecoration(
              labelText: 'Athlete ID',
              hintText: 'i123456',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: apiKey,
            enabled: !loading,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: connected ? 'New API key (optional)' : 'API key',
              border: const OutlineInputBorder(),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!),
          ],
          if (wellness != null) ...[
            const SizedBox(height: 10),
            Text(
              'Resting HR: ${wellness.heartRate.latest.round()} bpm · '
              '${wellness.hrv == null ? 'HRV not available' : 'HRV ${wellness.hrv!.latest.round()} ms (${wellness.hrv!.source})'} · '
              '${wellness.heartRate.sampleCount}-day wellness history',
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: loading ? null : _connect,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: Text(connected ? 'Update connection' : 'Connect'),
              ),
            ),
            if (connected) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sync rides now',
                onPressed: loading ? null : _sync,
                icon: const Icon(Icons.sync),
              ),
              IconButton(
                tooltip: 'Disconnect and remove credentials',
                onPressed: loading ? null : _disconnect,
                icon: const Icon(Icons.link_off),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(
            'Your API key is encrypted by Android and is never stored in the app source.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    athlete.dispose();
    apiKey.dispose();
    super.dispose();
  }
}
