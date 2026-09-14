import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';

class WorkoutCatalogueQuery {
  const WorkoutCatalogueQuery({
    this.family,
    this.phase,
    this.minimumDurationMinutes,
    this.maximumDurationMinutes,
    this.availableEquipment = const {},
  });

  final WorkoutFamily? family;
  final WorkoutCataloguePhase? phase;
  final int? minimumDurationMinutes;
  final int? maximumDurationMinutes;
  final Set<WorkoutEquipment> availableEquipment;
}

abstract interface class WorkoutCatalogueRepository {
  Future<List<WorkoutVariant>> find(WorkoutCatalogueQuery query);

  Future<WorkoutVariant?> getById(WorkoutVariantId id);

  Future<List<WorkoutProgression>> progressionsFor(WorkoutVariantId id);
}
