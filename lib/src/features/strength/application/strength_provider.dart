import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_training_load.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_progression.dart';

final strengthProfileProvider = StreamProvider<StrengthProfile?>(
  (ref) => ref.watch(databaseProvider).watchStrengthProfile(),
);
final strengthSessionsProvider = StreamProvider<List<StrengthSession>>(
  (ref) => ref.watch(databaseProvider).watchStrengthSessions(),
);
final strengthSetsProvider = StreamProvider.family<List<StrengthSet>, int>(
  (ref, id) => ref.watch(databaseProvider).watchStrengthSets(id),
);

final strengthWorkloadsProvider = FutureProvider<List<StrengthWorkoutLoad>>(
  (ref) async {
    final sessions = await ref.watch(strengthSessionsProvider.future);
    final database = ref.watch(databaseProvider);
    final workloads = <StrengthWorkoutLoad>[];
    for (final session
        in sessions.where((value) => value.completedAt != null)) {
      final sets = (await database.getStrengthSets(session.id))
          .where((value) => value.completed)
          .toList();
      if (sets.isEmpty) continue;
      final completedAt = session.completedAt!;
      final minutes =
          completedAt.difference(session.startedAt).inMinutes.clamp(1, 180);
      final volume = sets.fold<double>(
        0,
        (sum, set) => sum + set.weightKg * set.completedReps,
      );
      workloads.add(StrengthWorkoutLoad(
        sessionId: session.id,
        startedAt: session.startedAt,
        completedAt: completedAt,
        durationMinutes: minutes,
        completedSets: sets.length,
        volumeKg: volume,
        load: estimateStrengthTrainingLoad(
          durationMinutes: minutes,
          completedSets: sets.length,
          volumeKg: volume,
        ),
      ));
    }
    return workloads;
  },
);

final strengthProgressionsProvider =
    FutureProvider<Map<String, StrengthProgression>>((ref) async {
  final sessions = await ref.watch(strengthSessionsProvider.future);
  final database = ref.watch(databaseProvider);
  final history = <String, List<StrengthSetPerformance>>{};
  for (final session in sessions.where((value) => value.completedAt != null)) {
    final sets = await database.getStrengthSets(session.id);
    for (final set in sets.where(
      (value) => value.completed && !value.exerciseId.startsWith('mobility_'),
    )) {
      history.putIfAbsent(set.exerciseId, () => []).add(
            StrengthSetPerformance(
              sessionId: session.id,
              completedAt: session.completedAt!,
              weightKg: set.weightKg,
              reps: set.completedReps,
              targetReps: set.targetReps,
            ),
          );
    }
  }
  return {
    for (final entry in history.entries)
      if (calculateStrengthProgression(entry.key, entry.value)
          case final progression?)
        entry.key: progression,
  };
});

final strengthControllerProvider = Provider(StrengthController.new);

class StrengthController {
  StrengthController(this.ref);
  final Ref ref;

  Future<void> saveProfile({
    required String goal,
    required String location,
    required String experience,
    required int daysPerWeek,
    required int sessionMinutes,
    required List<String> equipment,
  }) =>
      ref.read(databaseProvider).saveStrengthProfile(
            StrengthProfilesCompanion.insert(
              goal: goal,
              location: location,
              experience: experience,
              daysPerWeek: daysPerWeek,
              sessionMinutes: sessionMinutes,
              equipment: equipment.join(','),
            ),
          );

  Future<int> startSession(String routineName, {DateTime? startedAt}) =>
      ref.read(databaseProvider).createStrengthSession(
            StrengthSessionsCompanion.insert(
              routineName: routineName,
              startedAt: startedAt ?? DateTime.now(),
            ),
          );

  Future<void> saveSet({
    required int sessionId,
    required String exerciseId,
    required int setNumber,
    required int targetReps,
    required int completedReps,
    required double weightKg,
  }) =>
      ref.read(databaseProvider).saveStrengthSet(
            StrengthSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              setNumber: setNumber,
              targetReps: targetReps,
              completedReps: Value(completedReps),
              weightKg: Value(weightKg),
              completed: const Value(true),
            ),
          );

  Future<void> completeSession(int id) =>
      ref.read(databaseProvider).completeStrengthSession(id);

  Future<void> deleteSession(int id) =>
      ref.read(databaseProvider).deleteStrengthSession(id);
}
