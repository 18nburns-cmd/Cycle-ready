import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart';

abstract interface class AthleteRepository {
  Future<AthleteState> getState();
  Stream<AthleteState> watchState();
  Future<void> saveState(AthleteState state);
  Future<List<AthleteState>> getHistory({int? limit});
  Stream<List<AthleteState>> watchHistory();
}
