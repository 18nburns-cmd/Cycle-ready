import 'package:cycle_ready/src/features/athlete/domain/athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state_trend.dart';

class AthleteStateService {
  const AthleteStateService(this.repository);

  final AthleteRepository repository;

  Future<AthleteState> load() => repository.getState();

  Stream<AthleteState> watch() => repository.watchState();

  Future<void> save(AthleteState state) => repository.saveState(state);

  Future<AthleteStateTrend?> loadTrend({int? limit}) async =>
      calculateAthleteStateTrend(await repository.getHistory(limit: limit));
}
