import 'package:cycle_ready/src/core/database/app_database.dart' as db;
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_state.dart'
    as domain;
import 'package:drift/drift.dart' show Value;

class DriftAthleteRepository implements AthleteRepository {
  const DriftAthleteRepository(this.database, this.profileRepository);

  final db.AppDatabase database;
  final AthleteProfileRepository profileRepository;

  @override
  Future<domain.AthleteState> getState() async {
    final row = await database.getAthleteState();
    if (row == null) throw StateError('Athlete state has not been calculated');
    return _fromCurrent(row, await profileRepository.getProfile());
  }

  @override
  Stream<domain.AthleteState> watchState() async* {
    final profile = await profileRepository.getProfile();
    yield* database.watchAthleteState().where((row) => row != null).map(
          (row) => _fromCurrent(row!, profile),
        );
  }

  @override
  Future<void> saveState(domain.AthleteState state) async {
    await profileRepository.saveProfile(state.profile);
    await database.transaction(() async {
      await database.saveAthleteState(
        db.AthleteStatesCompanion.insert(
          id: const Value(1),
          updatedAt: state.updatedAt,
          fitness: state.fitness,
          fatigue: state.fatigue,
          freshness: state.freshness,
          readiness: state.readiness,
          recovery: state.recovery,
          hrvTrend: Value(state.hrvTrend),
          weightTrend: Value(state.weightTrend),
        ),
      );
      await database.saveAthleteStateHistory(
        db.AthleteStateHistoryCompanion.insert(
          updatedAt: state.updatedAt,
          fitness: state.fitness,
          fatigue: state.fatigue,
          freshness: state.freshness,
          readiness: state.readiness,
          recovery: state.recovery,
          hrvTrend: Value(state.hrvTrend),
          weightTrend: Value(state.weightTrend),
        ),
      );
    });
  }

  @override
  Future<List<domain.AthleteState>> getHistory({int? limit}) async {
    final profile = await profileRepository.getProfile();
    final rows = await database.getAthleteStateHistory(limit: limit);
    final states =
        rows.map((row) => _fromHistory(row, profile)).toList(growable: false);
    return states.reversed.toList(growable: false);
  }

  @override
  Stream<List<domain.AthleteState>> watchHistory() async* {
    final profile = await profileRepository.getProfile();
    yield* database.watchAthleteStateHistory().map(
          (rows) => rows
              .map((row) => _fromHistory(row, profile))
              .toList(growable: false),
        );
  }

  domain.AthleteState _fromCurrent(
    db.AthleteState row,
    AthleteProfile profile,
  ) =>
      _createState(
        profile: profile,
        updatedAt: row.updatedAt,
        fitness: row.fitness,
        fatigue: row.fatigue,
        freshness: row.freshness,
        readiness: row.readiness,
        recovery: row.recovery,
        hrvTrend: row.hrvTrend,
        weightTrend: row.weightTrend,
      );

  domain.AthleteState _fromHistory(
    db.AthleteStateHistoryData row,
    AthleteProfile profile,
  ) =>
      _createState(
        profile: profile,
        updatedAt: row.updatedAt,
        fitness: row.fitness,
        fatigue: row.fatigue,
        freshness: row.freshness,
        readiness: row.readiness,
        recovery: row.recovery,
        hrvTrend: row.hrvTrend,
        weightTrend: row.weightTrend,
      );

  domain.AthleteState _createState({
    required AthleteProfile profile,
    required DateTime updatedAt,
    required double fitness,
    required double fatigue,
    required double freshness,
    required double readiness,
    required double recovery,
    required double? hrvTrend,
    required double? weightTrend,
  }) =>
      domain.AthleteState(
        profile: profile,
        updatedAt: updatedAt,
        fitness: fitness,
        fatigue: fatigue,
        freshness: freshness,
        readiness: readiness,
        recovery: recovery,
        hrvTrend: hrvTrend,
        weightTrend: weightTrend,
      );
}
