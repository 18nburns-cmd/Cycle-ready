import 'package:cycle_ready/src/features/athlete/data/in_memory_athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository returns and watches the current state', () async {
    final repository = InMemoryAthleteRepository(_state());
    addTearDown(repository.dispose);

    final states = repository.watchState();
    expect(await states.first, same(await repository.getState()));

    final replacement = _state().copyWith(readiness: 82);
    await repository.saveState(replacement);

    expect(await repository.getState(), same(replacement));
  });

  test('watchState emits saved states after its initial value', () async {
    final initial = _state();
    final repository = InMemoryAthleteRepository(initial);
    addTearDown(repository.dispose);
    final states = repository.watchState();
    final values = <AthleteState>[];
    final subscription = states.listen(values.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    final replacement = _state().copyWith(fatigue: 55);
    await repository.saveState(replacement);
    await Future<void>.delayed(Duration.zero);

    expect(values, [same(initial), same(replacement)]);
  });

  test('history retains saves in chronological insertion order', () async {
    final repository = InMemoryAthleteRepository(_state());
    addTearDown(repository.dispose);
    final first = _state();
    final second = _state().copyWith(readiness: 82);

    await repository.saveState(first);
    await repository.saveState(second);

    expect(await repository.getHistory(limit: 1), [same(second)]);
    expect(await repository.getHistory(), [same(first), same(second)]);
  });
}

AthleteState _state() => AthleteState(
      profile: const AthleteProfile(
        name: 'Neil',
        experienceLevel: 'intermediate',
        ftp: 240,
        maximumHeartRate: 190,
        restingHeartRate: 50,
        weightKg: 72,
        weeklyLoadTarget: 400,
      ),
      updatedAt: DateTime.utc(2026, 8, 25),
      fitness: 60,
      fatigue: 40,
      freshness: 60,
      readiness: 70,
      recovery: 75,
    );
