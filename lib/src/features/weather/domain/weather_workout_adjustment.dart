import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';

AdaptiveWorkout applyWeatherToWorkout(
  AdaptiveWorkout workout, {
  required RideWeather? weather,
  required bool hasIndoorTrainer,
  RidingSafetyProfile safetyProfile = RidingSafetyProfile.balanced,
}) {
  final thresholds = RidingSafetyThresholds.forProfile(safetyProfile);
  if (weather == null ||
      !weather.isUnsafe(thresholds) ||
      workout.setting != RideSetting.outdoor) {
    return workout;
  }
  final setting = hasIndoorTrainer ? RideSetting.indoor : RideSetting.flexible;
  final label = hasIndoorTrainer ? 'Indoor' : 'Indoor or outdoor';
  final action = hasIndoorTrainer
      ? 'The session has been moved indoors.'
      : 'No indoor trainer is configured, so confirm local conditions before riding.';
  return AdaptiveWorkout(
    day: workout.day,
    type: workout.type,
    title: workout.title,
    durationMinutes: workout.durationMinutes,
    targetLoad: workout.targetLoad,
    prescription: workout.prescription.replaceFirst('Outdoor', label),
    reason:
        '${workout.reason} Forecast ${weather.safetyReason(thresholds)}. $action',
    setting: setting,
    startMinutes: workout.startMinutes,
  );
}
