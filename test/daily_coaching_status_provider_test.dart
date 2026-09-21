import 'dart:async';

import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/cloud_account.dart';
import 'package:cycle_ready/src/features/coaching/application/daily_coaching_status_provider.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = CloudAccount(id: 'user-1', email: 'athlete@example.com');

  test('waits for authentication before requesting server coaching', () async {
    final accounts = StreamController<CloudAccount?>();
    final repository = _FakeRepository();
    final container = ProviderContainer(overrides: [
      cloudAccountProvider.overrideWith((ref) => accounts.stream),
      dailyCoachingStatusRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(() async {
      container.dispose();
      await accounts.close();
    });

    final subscription = container.listen(
      todayDailyCoachingRecommendationProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 0);

    accounts.add(account);
    final recommendation =
        await container.read(todayDailyCoachingRecommendationProvider.future);

    expect(recommendation?.decision, 'KEEP');
    expect(repository.calls, 1);
  });

  test('retries a transient server failure while Today remains open', () async {
    final repository = _FakeRepository(failuresBeforeSuccess: 1);
    final container = ProviderContainer(overrides: [
      cloudAccountProvider.overrideWith((ref) => Stream.value(account)),
      dailyCoachingStatusRepositoryProvider.overrideWithValue(repository),
      serverCoachingRetryDelayProvider
          .overrideWithValue(const Duration(milliseconds: 10)),
    ]);
    addTearDown(container.dispose);

    final subscription = container.listen(
      todayDailyCoachingRecommendationProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(todayDailyCoachingRecommendationProvider.future),
      throwsStateError,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final recommendation =
        await container.read(todayDailyCoachingRecommendationProvider.future);
    expect(recommendation?.decision, 'KEEP');
    expect(repository.calls, 2);
  });
}

class _FakeRepository implements DailyCoachingStatusRepository {
  _FakeRepository({this.failuresBeforeSuccess = 0});

  final int failuresBeforeSuccess;
  int calls = 0;

  @override
  Future<DailyCoachingRecommendation?> fetchToday() async {
    calls++;
    if (calls <= failuresBeforeSuccess) {
      throw StateError('Temporary network failure');
    }
    return DailyCoachingRecommendation(
      date: DateTime(2026, 9, 15),
      decision: 'KEEP',
      explanation: 'Server recommendation is available.',
      confidence: .8,
      modelVersion: 'test-v1',
    );
  }

  @override
  Future<DailyCoachingStatus> fetchStatus() => throw UnimplementedError();
}
