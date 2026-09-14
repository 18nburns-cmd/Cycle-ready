import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository contract reads, watches and saves athlete state', () async {
    final repository = _MemoryAthleteRepository(_state());

    expect(await repository.getState(), same(repository.state));
    expect(await repository.watchState().first, same(repository.state));

    final replacement = _state().copyWith(readiness: 82);
    await repository.saveState(replacement);

    expect(repository.state, same(replacement));
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

class _MemoryAthleteRepository implements AthleteRepository {
  _MemoryAthleteRepository(this.state);

  AthleteState state;

  @override
  Future<AthleteState> getState() async => state;

  @override
  Stream<AthleteState> watchState() => Stream.value(state);

  @override
  Future<List<AthleteState>> getHistory({int? limit}) async => const [];

  @override
  Stream<List<AthleteState>> watchHistory() => Stream.value(const []);

  @override
  Future<void> saveState(AthleteState value) async => state = value;
}
