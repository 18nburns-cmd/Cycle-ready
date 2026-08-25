import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile_repository.dart';
import 'package:drift/drift.dart' show Value;

class DriftAthleteProfileRepository implements AthleteProfileRepository {
  const DriftAthleteProfileRepository(this.database);

  final AppDatabase database;

  @override
  Future<AthleteProfile> getProfile() async =>
      _toDomain(await database.getAthleteSettings());

  @override
  Stream<AthleteProfile> watchProfile() async* {
    await database.getAthleteSettings();
    yield* database.watchAthleteSettings().where((row) => row != null).map(
          (row) => _toDomain(row!),
        );
  }

  @override
  Future<void> saveProfile(AthleteProfile profile) =>
      database.saveAthleteSettings(
        AthleteSettingsCompanion.insert(
          id: const Value(1),
          athleteName: Value(profile.name),
          age: Value(profile.age),
          heightCm: Value(profile.heightCm),
          experienceLevel: Value(profile.experienceLevel),
          bikeDetails: Value(profile.bikeDetails),
          equipment: Value(profile.equipment),
          hasPowerMeter: Value(profile.hasPowerMeter),
          hasIndoorTrainer: Value(profile.hasIndoorTrainer),
          preferredRideTimeMinutes: Value(profile.preferredRideTimeMinutes),
          nutritionPreferences: Value(profile.nutritionPreferences),
          injuryHistory: Value(profile.injuryHistory),
          trainingLocation: Value(profile.trainingLocation),
          ridingSafetyProfile: Value(profile.ridingSafetyProfile),
          ftp: Value(profile.ftp),
          thresholdHeartRate: Value(profile.thresholdHeartRate),
          maximumHeartRate: Value(profile.maximumHeartRate),
          restingHeartRate: Value(profile.restingHeartRate),
          weightKg: Value(profile.weightKg),
          weeklyLoadTarget: Value(profile.weeklyLoadTarget),
        ),
      );

  AthleteProfile _toDomain(AthleteSetting row) => AthleteProfile(
        name: row.athleteName,
        age: row.age,
        heightCm: row.heightCm,
        experienceLevel: row.experienceLevel,
        ftp: row.ftp,
        thresholdHeartRate: row.thresholdHeartRate,
        maximumHeartRate: row.maximumHeartRate,
        restingHeartRate: row.restingHeartRate,
        weightKg: row.weightKg,
        weeklyLoadTarget: row.weeklyLoadTarget,
        bikeDetails: row.bikeDetails,
        equipment: row.equipment,
        hasPowerMeter: row.hasPowerMeter,
        hasIndoorTrainer: row.hasIndoorTrainer,
        preferredRideTimeMinutes: row.preferredRideTimeMinutes,
        nutritionPreferences: row.nutritionPreferences,
        injuryHistory: row.injuryHistory,
        trainingLocation: row.trainingLocation,
        ridingSafetyProfile: row.ridingSafetyProfile,
      );
}
