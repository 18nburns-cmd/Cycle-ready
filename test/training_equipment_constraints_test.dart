import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const indoor = CyclingAvailability(
    weekday: DateTime.tuesday,
    enabled: true,
    startMinutes: 18 * 60,
    durationMinutes: 60,
    setting: RideSetting.indoor,
  );

  test('indoor-only slots become flexible without an indoor trainer', () {
    final result = applyEquipmentConstraints(
      const [indoor],
      hasIndoorTrainer: false,
    );

    expect(result.single.setting, RideSetting.flexible);
  });

  test('indoor preference remains when a trainer is available', () {
    final result = applyEquipmentConstraints(
      const [indoor],
      hasIndoorTrainer: true,
    );

    expect(result.single.setting, RideSetting.indoor);
  });
}
