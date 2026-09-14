import 'package:cycle_ready/src/features/athlete/application/athlete_state_service.dart';
import 'package:cycle_ready/src/features/athlete/data/in_memory_athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service delegates state reads, watches and saves', () async {
    final repository = InMemoryAthleteRepository(_state());
    addTearDown(repository.dispose);
    final service = AthleteStateService(repository);

    expect(await service.load(), same(await repository.getState()));
    expect(await service.watch().first, same(await repository.getState()));

    final replacement = _state().copyWith(readiness: 88);
    await service.save(replacement);

    expect(await service.load(), same(replacement));
  });

  test('service calculates a trend from repository history', () async {
    final repository = InMemoryAthleteRepository(_state());
    addTearDown(repository.dispose);
    final service = AthleteStateService(repository);
    await service.save(_state());
    await service.save(_state().copyWith(fitness: 65, readiness: 80));

    final trend = await service.loadTrend();

    expect(trend, isNotNull);
    expect(trend!.fitnessChange, 5);
    expect(trend.readinessChange, 10);
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
