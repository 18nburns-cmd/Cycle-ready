import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/athlete/data/drift_athlete_profile_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository maps profile without leaking Drift models', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAthleteProfileRepository(database);
    const expected = AthleteProfile(
      name: 'Neil',
      age: 42,
      heightCm: 178,
      experienceLevel: 'advanced',
      ftp: 255,
      thresholdHeartRate: 166,
      maximumHeartRate: 188,
      restingHeartRate: 48,
      weightKg: 71.5,
      weeklyLoadTarget: 420,
      bikeDetails: 'Carbon road bike',
      equipment: 'Power meter and HR strap',
      hasPowerMeter: true,
      hasIndoorTrainer: false,
      preferredRideTimeMinutes: 7 * 60,
      nutritionPreferences: 'No dairy before riding',
      injuryHistory: 'Monitor left knee',
      trainingLocation: 'Newcastle upon Tyne',
      ridingSafetyProfile: 'cautious',
    );

    await repository.saveProfile(expected);
    final actual = await repository.getProfile();

    expect(actual.name, expected.name);
    expect(actual.age, expected.age);
    expect(actual.heightCm, expected.heightCm);
    expect(actual.experienceLevel, expected.experienceLevel);
    expect(actual.ftp, expected.ftp);
    expect(actual.thresholdHeartRate, expected.thresholdHeartRate);
    expect(actual.maximumHeartRate, expected.maximumHeartRate);
    expect(actual.restingHeartRate, expected.restingHeartRate);
    expect(actual.weightKg, expected.weightKg);
    expect(actual.weeklyLoadTarget, expected.weeklyLoadTarget);
    expect(actual.bikeDetails, expected.bikeDetails);
    expect(actual.equipment, expected.equipment);
    expect(actual.hasPowerMeter, expected.hasPowerMeter);
    expect(actual.hasIndoorTrainer, expected.hasIndoorTrainer);
    expect(actual.preferredRideTimeMinutes, expected.preferredRideTimeMinutes);
    expect(actual.nutritionPreferences, expected.nutritionPreferences);
    expect(actual.injuryHistory, expected.injuryHistory);
    expect(actual.trainingLocation, expected.trainingLocation);
    expect(actual.ridingSafetyProfile, expected.ridingSafetyProfile);
  });

  test('watchProfile creates and emits the default profile', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAthleteProfileRepository(database);

    final profile = await repository.watchProfile().first;

    expect(profile.name, 'Neil');
    expect(profile.experienceLevel, 'intermediate');
    expect(profile.ridingSafetyProfile, 'balanced');
  });
}
