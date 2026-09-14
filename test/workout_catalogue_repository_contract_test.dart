import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue query carries provider-neutral selection constraints', () {
    const query = WorkoutCatalogueQuery(
      family: WorkoutFamily.threshold,
      phase: WorkoutCataloguePhase.build,
      minimumDurationMinutes: 45,
      maximumDurationMinutes: 75,
      availableEquipment: {
        WorkoutEquipment.bicycle,
        WorkoutEquipment.powerMeter,
      },
    );

    expect(query.family, WorkoutFamily.threshold);
    expect(query.phase, WorkoutCataloguePhase.build);
    expect(query.maximumDurationMinutes, 75);
    expect(query.availableEquipment, contains(WorkoutEquipment.powerMeter));
  });
}
