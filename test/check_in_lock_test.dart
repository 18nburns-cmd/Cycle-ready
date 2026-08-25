import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily check-in accepts the first save and rejects later changes',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    await container.read(recoveryControllerProvider.future);
    final controller = container.read(recoveryControllerProvider.notifier);

    final first = await controller.saveCheckIn(
      fatigue: 2,
      soreness: 3,
      stress: 2,
      motivation: 5,
    );
    final second = await controller.saveCheckIn(
      fatigue: 5,
      soreness: 5,
      stress: 5,
      motivation: 1,
    );
    final saved = await database.recoveryForDay(DateTime.now());

    expect(first, isTrue);
    expect(second, isFalse);
    expect(saved?.fatigue, 2);
    expect(saved?.soreness, 3);
    expect(saved?.stress, 2);
    expect(saved?.motivation, 5);
  });
}
