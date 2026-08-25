import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('athlete profile persists identity and core physiology', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.saveAthleteSettings(
      AthleteSettingsCompanion.insert(
        athleteName: const Value('Neil'),
        age: const Value(42),
        heightCm: const Value(178),
        experienceLevel: const Value('advanced'),
        ftp: const Value(255),
        thresholdHeartRate: const Value(166),
        bikeDetails: const Value('Road bike'),
        equipment: const Value('HR strap'),
        hasPowerMeter: const Value(true),
        hasIndoorTrainer: const Value(false),
        preferredRideTimeMinutes: const Value(390),
        nutritionPreferences: const Value('Vegetarian'),
        injuryHistory: const Value('Previous knee irritation'),
        ridingSafetyProfile: const Value('resilient'),
      ),
    );

    final profile = await database.getAthleteSettings();
    expect(profile.athleteName, 'Neil');
    expect(profile.age, 42);
    expect(profile.heightCm, 178);
    expect(profile.experienceLevel, 'advanced');
    expect(profile.ftp, 255);
    expect(profile.thresholdHeartRate, 166);
    expect(profile.bikeDetails, 'Road bike');
    expect(profile.hasIndoorTrainer, isFalse);
    expect(profile.preferredRideTimeMinutes, 390);
    expect(profile.nutritionPreferences, 'Vegetarian');
    expect(profile.injuryHistory, contains('knee'));
    expect(profile.ridingSafetyProfile, 'resilient');
  });

  test('new athlete profile has safe defaults and optional measurements',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final profile = await database.getAthleteSettings();
    expect(profile.athleteName, 'Neil');
    expect(profile.experienceLevel, 'intermediate');
    expect(profile.age, isNull);
    expect(profile.heightCm, isNull);
    expect(profile.thresholdHeartRate, isNull);
    expect(profile.hasPowerMeter, isTrue);
    expect(profile.hasIndoorTrainer, isTrue);
    expect(profile.preferredRideTimeMinutes, 18 * 60);
    expect(profile.ridingSafetyProfile, 'balanced');
  });
}
