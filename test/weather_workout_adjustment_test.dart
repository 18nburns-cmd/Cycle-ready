import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';
import 'package:cycle_ready/src/features/weather/domain/weather_workout_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final workout = AdaptiveWorkout(
    day: DateTime(2026, 8, 29),
    type: SessionType.endurance,
    title: 'Endurance 120',
    durationMinutes: 120,
    targetLoad: 80,
    prescription: 'Outdoor · Zone 2',
    reason: 'Build aerobic durability.',
    setting: RideSetting.outdoor,
  );

  test('dangerous wind moves an outdoor workout indoors with a trainer', () {
    final adjusted = applyWeatherToWorkout(
      workout,
      weather: RideWeather(
        at: DateTime(2026, 8, 29, 9),
        temperatureC: 15,
        precipitationMm: 0,
        precipitationProbability: 10,
        windGustKph: 62,
        weatherCode: 2,
      ),
      hasIndoorTrainer: true,
    );

    expect(adjusted.setting, RideSetting.indoor);
    expect(adjusted.prescription, startsWith('Indoor'));
    expect(adjusted.reason, contains('wind gusts above your outdoor limit'));
  });

  test('unsafe weather stays flexible when no trainer is configured', () {
    final adjusted = applyWeatherToWorkout(
      workout,
      weather: RideWeather(
        at: DateTime(2026, 8, 29, 9),
        temperatureC: 0,
        precipitationMm: 0,
        precipitationProbability: 10,
        windGustKph: 10,
        weatherCode: 1,
      ),
      hasIndoorTrainer: false,
    );

    expect(adjusted.setting, RideSetting.flexible);
    expect(adjusted.reason, contains('confirm local conditions'));
  });

  test('safe forecast does not alter the prescription', () {
    final adjusted = applyWeatherToWorkout(
      workout,
      weather: RideWeather(
        at: DateTime(2026, 8, 29, 9),
        temperatureC: 17,
        precipitationMm: .1,
        precipitationProbability: 20,
        windGustKph: 25,
        weatherCode: 2,
      ),
      hasIndoorTrainer: true,
    );

    expect(identical(adjusted, workout), isTrue);
  });

  test('safety profile changes when borderline weather moves indoors', () {
    final weather = RideWeather(
      at: DateTime(2026, 8, 29, 9),
      temperatureC: 3,
      precipitationMm: 0,
      precipitationProbability: 30,
      windGustKph: 30,
      weatherCode: 2,
    );

    final cautious = applyWeatherToWorkout(
      workout,
      weather: weather,
      hasIndoorTrainer: true,
      safetyProfile: RidingSafetyProfile.cautious,
    );
    final balanced = applyWeatherToWorkout(
      workout,
      weather: weather,
      hasIndoorTrainer: true,
      safetyProfile: RidingSafetyProfile.balanced,
    );

    expect(cautious.setting, RideSetting.indoor);
    expect(identical(balanced, workout), isTrue);
  });
}
