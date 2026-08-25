class AthleteProfile {
  const AthleteProfile({
    required this.name,
    required this.experienceLevel,
    required this.ftp,
    required this.maximumHeartRate,
    required this.restingHeartRate,
    required this.weightKg,
    required this.weeklyLoadTarget,
    this.age,
    this.heightCm,
    this.thresholdHeartRate,
    this.bikeDetails = '',
    this.equipment = '',
    this.hasPowerMeter = true,
    this.hasIndoorTrainer = true,
    this.preferredRideTimeMinutes = 18 * 60,
    this.nutritionPreferences = '',
    this.injuryHistory = '',
    this.trainingLocation = '',
    this.ridingSafetyProfile = 'balanced',
  });

  final String name;
  final int? age;
  final double? heightCm;
  final String experienceLevel;
  final int ftp;
  final int? thresholdHeartRate;
  final int maximumHeartRate;
  final int restingHeartRate;
  final double weightKg;
  final int weeklyLoadTarget;
  final String bikeDetails;
  final String equipment;
  final bool hasPowerMeter;
  final bool hasIndoorTrainer;
  final int preferredRideTimeMinutes;
  final String nutritionPreferences;
  final String injuryHistory;
  final String trainingLocation;
  final String ridingSafetyProfile;

  AthleteProfile copyWith({double? weightKg}) => AthleteProfile(
        name: name,
        age: age,
        heightCm: heightCm,
        experienceLevel: experienceLevel,
        ftp: ftp,
        thresholdHeartRate: thresholdHeartRate,
        maximumHeartRate: maximumHeartRate,
        restingHeartRate: restingHeartRate,
        weightKg: weightKg ?? this.weightKg,
        weeklyLoadTarget: weeklyLoadTarget,
        bikeDetails: bikeDetails,
        equipment: equipment,
        hasPowerMeter: hasPowerMeter,
        hasIndoorTrainer: hasIndoorTrainer,
        preferredRideTimeMinutes: preferredRideTimeMinutes,
        nutritionPreferences: nutritionPreferences,
        injuryHistory: injuryHistory,
        trainingLocation: trainingLocation,
        ridingSafetyProfile: ridingSafetyProfile,
      );
}
