import 'dart:async';

import 'package:cycle_ready/src/features/athlete/domain/athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';

class InMemoryAthleteRepository implements AthleteRepository {
  InMemoryAthleteRepository(this._state);

  AthleteState _state;
  final List<AthleteState> _history = [];
  final StreamController<AthleteState> _changes =
      StreamController<AthleteState>.broadcast();

  @override
  Future<AthleteState> getState() async => _state;

  @override
  Stream<AthleteState> watchState() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<void> saveState(AthleteState state) async {
    _state = state;
    _history.add(state);
    _changes.add(state);
  }

  @override
  Future<List<AthleteState>> getHistory({int? limit}) async {
    final history = List<AthleteState>.unmodifiable(_history);
    if (limit == null) return history;
    if (limit <= 0) return const [];
    final start = history.length > limit ? history.length - limit : 0;
    return history.skip(start).toList(growable: false);
  }

  @override
  Stream<List<AthleteState>> watchHistory() async* {
    yield List<AthleteState>.unmodifiable(_history);
    yield* _changes.stream
        .map((_) => List<AthleteState>.unmodifiable(_history));
  }

  Future<void> dispose() => _changes.close();
}
