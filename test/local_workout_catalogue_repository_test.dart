import 'package:cycle_ready/src/features/coaching/data/local_workout_catalogue_repository.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = LocalWorkoutCatalogueRepository(ftp: 250);

  test('adapts existing generated workouts behind catalogue queries', () async {
    final variants = await repository.find(const WorkoutCatalogueQuery(
      family: WorkoutFamily.threshold,
      phase: WorkoutCataloguePhase.build,
      minimumDurationMinutes: 45,
      maximumDurationMinutes: 90,
      availableEquipment: {WorkoutEquipment.bicycle},
    ));

    expect(variants, isNotEmpty);
    expect(variants.every((item) => item.family == WorkoutFamily.threshold),
        isTrue);
    expect(variants.map((item) => item.difficulty).toSet(), hasLength(3));
  });

  test('gets a materialized variant by its stable id', () async {
    final variants = await repository.find(const WorkoutCatalogueQuery());
    final found = await repository.getById(variants.first.id);

    expect(found?.id, variants.first.id);
  });

  test('equipment query excludes unsupported requirements', () async {
    final variants = await repository.find(const WorkoutCatalogueQuery(
      availableEquipment: {WorkoutEquipment.heartRateMonitor},
    ));

    expect(variants, isEmpty);
  });
}
