import 'package:cycle_ready/src/features/integrations/domain/training_provider_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('future providers synchronize through one provider-neutral contract',
      () async {
    final coros = _FakeProvider(
      id: 'coros',
      capabilities: const {TrainingProviderCapability.activitiesRead},
      batch: ProviderSyncBatch(
        activities: [
          ProviderActivity(
            externalId: 'ride-1',
            startedAt: DateTime.utc(2026, 9, 3),
            durationSeconds: 3600,
          ),
        ],
        nextCursor: 'page-2',
      ),
    );
    final futureHealth = _FakeProvider(
      id: 'future-health',
      capabilities: const {TrainingProviderCapability.wellnessRead},
      batch: ProviderSyncBatch(
        wellness: [ProviderWellness(day: DateTime.utc(2026, 9, 3))],
      ),
    );

    final results = await TrainingProviderSyncOrchestrator(
      [coros, futureHealth],
    ).fetchAll(cursors: const {'coros': 'page-1'});

    expect(results[0].activityCount, 1);
    expect(results[0].nextCursor, 'page-2');
    expect(coros.receivedCursor, 'page-1');
    expect(results[1].wellnessCount, 1);
    expect(results, everyElement(isA<ProviderSyncResult>()));
  });

  test('one provider failure does not stop another provider', () async {
    final results = await TrainingProviderSyncOrchestrator([
      _FakeProvider(id: 'offline', error: StateError('unavailable')),
      _FakeProvider(id: 'healthy'),
    ]).fetchAll();
    expect(results.first.error, isA<StateError>());
    expect(results.last.error, isNull);
  });

  test('adapters cannot emit data outside declared capabilities', () async {
    final result = (await TrainingProviderSyncOrchestrator([
      _FakeProvider(
        id: 'invalid',
        batch: ProviderSyncBatch(
          wellness: [ProviderWellness(day: DateTime.utc(2026))],
        ),
      ),
    ]).fetchAll())
        .single;
    expect(result.error, isA<StateError>());
  });
}

class _FakeProvider implements TrainingProviderAdapter {
  _FakeProvider({
    required this.id,
    this.capabilities = const {},
    this.batch = const ProviderSyncBatch(),
    this.error,
  });

  @override
  final String id;
  @override
  final Set<TrainingProviderCapability> capabilities;
  final ProviderSyncBatch batch;
  final Object? error;
  String? receivedCursor;

  @override
  Future<ProviderSyncBatch> fetchChanges({String? cursor}) async {
    receivedCursor = cursor;
    if (error != null) throw error!;
    return batch;
  }

  @override
  Future<bool> isConnected() async => true;
}
