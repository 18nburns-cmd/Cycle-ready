class RecoveryInput {
  const RecoveryInput({
    required this.sleepMinutes,
    required this.sleepTargetMinutes,
    required this.sleepQuality,
    required this.restingHeartRate,
    required this.baselineRestingHeartRate,
    this.hrvMilliseconds,
    this.baselineHrvMilliseconds,
    required this.recentTrainingLoad,
    required this.normalTrainingLoad,
    required this.fatigue,
    required this.soreness,
    required this.stress,
    required this.motivation,
    this.hasHealthData = false,
    this.hasSleepData = false,
    this.hasRecoverySignals = false,
    this.hasCheckIn = false,
  });

  final int sleepMinutes;
  final int sleepTargetMinutes;
  final double sleepQuality;
  final double restingHeartRate;
  final double baselineRestingHeartRate;
  final double? hrvMilliseconds;
  final double? baselineHrvMilliseconds;
  final double recentTrainingLoad;
  final double normalTrainingLoad;
  final int fatigue;
  final int soreness;
  final int stress;
  final int motivation;
  final bool hasHealthData;
  final bool hasSleepData;
  final bool hasRecoverySignals;
  final bool hasCheckIn;

  factory RecoveryInput.defaults() => const RecoveryInput(
        sleepMinutes: 438,
        sleepTargetMinutes: 480,
        sleepQuality: 82,
        restingHeartRate: 52,
        baselineRestingHeartRate: 50,
        hrvMilliseconds: 54,
        baselineHrvMilliseconds: 58,
        recentTrainingLoad: 340,
        normalTrainingLoad: 320,
        fatigue: 3,
        soreness: 2,
        stress: 2,
        motivation: 4,
        hasHealthData: false,
        hasSleepData: false,
        hasRecoverySignals: false,
        hasCheckIn: false,
      );

  RecoveryInput copyWith({
    int? sleepMinutes,
    double? sleepQuality,
    double? restingHeartRate,
    double? baselineRestingHeartRate,
    double? hrvMilliseconds,
    double? baselineHrvMilliseconds,
    double? recentTrainingLoad,
    int? fatigue,
    int? soreness,
    int? stress,
    int? motivation,
    bool? hasHealthData,
    bool? hasSleepData,
    bool? hasRecoverySignals,
    bool? hasCheckIn,
  }) =>
      RecoveryInput(
        sleepMinutes: sleepMinutes ?? this.sleepMinutes,
        sleepTargetMinutes: sleepTargetMinutes,
        sleepQuality: sleepQuality ?? this.sleepQuality,
        restingHeartRate: restingHeartRate ?? this.restingHeartRate,
        baselineRestingHeartRate:
            baselineRestingHeartRate ?? this.baselineRestingHeartRate,
        hrvMilliseconds: hrvMilliseconds ?? this.hrvMilliseconds,
        baselineHrvMilliseconds:
            baselineHrvMilliseconds ?? this.baselineHrvMilliseconds,
        recentTrainingLoad: recentTrainingLoad ?? this.recentTrainingLoad,
        normalTrainingLoad: normalTrainingLoad,
        fatigue: fatigue ?? this.fatigue,
        soreness: soreness ?? this.soreness,
        stress: stress ?? this.stress,
        motivation: motivation ?? this.motivation,
        hasHealthData: hasHealthData ?? this.hasHealthData,
        hasSleepData: hasSleepData ?? this.hasSleepData,
        hasRecoverySignals: hasRecoverySignals ?? this.hasRecoverySignals,
        hasCheckIn: hasCheckIn ?? this.hasCheckIn,
      );
}
