import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';

class UnplannedWorkoutChoice {
  const UnplannedWorkoutChoice(
      {required this.family,
      required this.type,
      required this.title,
      required this.durationMinutes,
      required this.targetLoad,
      required this.prescription,
      required this.reason,
      required this.confidence,
      required this.suitabilityScore,
      this.scoreComponents = const {},
      this.rejectionReasons = const [],
      this.recommended = false});
  final String family;
  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String prescription;
  final String reason;
  final double confidence;
  final double suitabilityScore;
  final Map<String, double> scoreComponents;
  final List<String> rejectionReasons;
  final bool recommended;
  bool get isEligible => rejectionReasons.isEmpty;

  UnplannedWorkoutChoice asRecommended() => UnplannedWorkoutChoice(
      family: family,
      type: type,
      title: title,
      durationMinutes: durationMinutes,
      targetLoad: targetLoad,
      prescription: prescription,
      reason: reason,
      confidence: confidence,
      suitabilityScore: suitabilityScore,
      scoreComponents: scoreComponents,
      rejectionReasons: rejectionReasons,
      recommended: true);

  UnplannedWorkoutChoice withEvaluation({
    required Map<String, double> components,
    required List<String> rejections,
  }) =>
      UnplannedWorkoutChoice(
        family: family,
        type: type,
        title: title,
        durationMinutes: durationMinutes,
        targetLoad: targetLoad,
        prescription: prescription,
        reason: reason,
        confidence: confidence,
        suitabilityScore: suitabilityScore,
        scoreComponents: Map.unmodifiable(components),
        rejectionReasons: List.unmodifiable(rejections),
        recommended: false,
      );
}

typedef _ScoreEvidence = ({double total, Map<String, double> components});

/// Domain service for an otherwise unplanned day. Presentation supplies
/// normalized evidence and receives provider-neutral choices.
class UnplannedWorkoutSelectionService {
  const UnplannedWorkoutSelectionService();

  List<UnplannedWorkoutChoice> evaluate({
    required int readiness,
    required int ftp,
    required double form,
    required double rampRate,
    required bool hardSessionWithin48Hours,
    required AdaptationTarget weeklyIntent,
    Map<WorkoutFamily, double> capabilityGaps = const {},
    Map<WorkoutFamily, WorkoutResponseSnapshot> learnedResponses = const {},
    Map<WorkoutFamily, double> recoveryCosts = const {},
    int? availableMinutes,
    RideSetting rideSetting = RideSetting.flexible,
    bool hasIndoorTrainer = true,
    bool outdoorConditionsSafe = true,
  }) {
    final constrained = readiness < 45 || form < -20 || rampRate > 10;
    final qualityAllowed = readiness >= 60 &&
        form >= -15 &&
        rampRate <= 8 &&
        !hardSessionWithin48Hours;
    final moderateAllowed = readiness >= 50 &&
        form >= -20 &&
        rampRate <= 10 &&
        !hardSessionWithin48Hours;
    final confidence = (.70 +
            (readiness - 50).clamp(0, 35) / 200 -
            (form < -10 ? .05 : 0) -
            (rampRate > 7 ? .05 : 0))
        .clamp(.55, .90);
    _ScoreEvidence suitability(String family, double demand) {
      final components = <String, double>{
        'readiness fit': 100 - (readiness - demand).abs() * 1.4,
        'form': form * .35,
        'ramp rate': -rampRate,
        'training-block intent': _intentBonus(family, weeklyIntent),
        'capability gap': _capabilityGapBonus(family, capabilityGaps),
        'historical response': _historicalResponseScore(
          family,
          learnedResponses,
          recoveryCosts,
        ),
      };
      final total =
          components.values.fold<double>(0, (sum, value) => sum + value);
      return (total: total.clamp(0, 100), components: components);
    }

    UnplannedWorkoutChoice evaluated(
      UnplannedWorkoutChoice choice,
      _ScoreEvidence evidence,
    ) {
      final rejections = <String>[];
      final isEasy =
          choice.family == 'Recovery' || choice.family == 'Endurance';
      final isModerate =
          choice.family == 'Tempo' || choice.family == 'Durability';
      if (constrained && !isEasy) {
        rejections.add('Recovery signals do not support this intensity.');
      } else if (!moderateAllowed && !isEasy) {
        rejections.add(
            'Hard-session spacing or recovery does not support this workout.');
      } else if (!qualityAllowed && !isEasy && !isModerate) {
        rejections.add('Readiness does not support high intensity.');
      }
      if (availableMinutes != null &&
          choice.durationMinutes > availableMinutes) {
        rejections.add('Exceeds the available training time.');
      }
      if (rideSetting == RideSetting.indoor && !hasIndoorTrainer) {
        rejections.add('An indoor trainer is unavailable.');
      }
      if (rideSetting == RideSetting.outdoor &&
          !outdoorConditionsSafe &&
          !hasIndoorTrainer) {
        rejections.add(
            'Outdoor conditions are unsafe and no indoor trainer is available.');
      }
      return choice.withEvaluation(
        components: evidence.components,
        rejections: rejections,
      );
    }

    final recovery = _steady(
        'Recovery',
        SessionType.recovery,
        'Recovery spin',
        35,
        15,
        0,
        55,
        ftp,
        'Very easy movement with minimal fatigue. Stop if you feel worse after warming up.',
        confidence,
        suitability('Recovery', 35).total,
        recommended: constrained);
    final endurance = _steady(
        'Endurance',
        SessionType.endurance,
        'Aerobic endurance',
        50,
        34,
        60,
        70,
        ftp,
        constrained
            ? 'Choose this only if the warm-up feels normal and keep it strictly easy.'
            : 'Adds aerobic work without compromising the next planned quality session.',
        confidence,
        suitability('Endurance', 52).total,
        recommended: !constrained && !moderateAllowed);
    final durability = _steady(
        'Durability',
        SessionType.endurance,
        'Endurance durability',
        80,
        55,
        62,
        72,
        ftp,
        'Builds aerobic durability when you have extra time, with a controlled recovery cost.',
        confidence,
        suitability('Durability', 58).total);

    final tempo = _interval(
        'Tempo',
        SessionType.tempo,
        'Tempo',
        3,
        '12 min',
        12,
        4,
        80,
        87,
        ftp,
        54,
        'Develops muscular endurance with less cost than threshold work.',
        confidence,
        suitabilityScore: suitability('Tempo', 58).total);

    final quality = [
      _interval(
          'Sweet spot',
          SessionType.tempo,
          'Sweet spot',
          3,
          '10 min',
          10,
          5,
          88,
          93,
          ftp,
          66,
          'Accumulates sustainable aerobic power with controlled fatigue.',
          confidence,
          suitabilityScore: suitability('Sweet spot', 65).total),
      _interval(
          'Threshold',
          SessionType.intervals,
          'Threshold',
          4,
          '8 min',
          8,
          4,
          98,
          103,
          ftp,
          78,
          'Develops sustained power close to FTP.',
          confidence,
          suitabilityScore: suitability('Threshold', 72).total),
      _interval(
          'VO2 max',
          SessionType.intervals,
          'VO2 max',
          5,
          '4 min',
          4,
          4,
          108,
          118,
          ftp,
          76,
          'Targets maximal aerobic power and repeatable hard efforts.',
          confidence,
          suitabilityScore: suitability('VO2 max', 80).total),
      _interval(
          'Climbing strength',
          SessionType.intervals,
          'Climbing strength',
          4,
          '8 min',
          8,
          4,
          88,
          94,
          ftp,
          70,
          'Builds torque and climbing durability at a controlled cadence.',
          confidence,
          suitabilityScore: suitability('Climbing strength', 68).total,
          detail: ' at 60–70 rpm'),
      _interval(
          'Anaerobic',
          SessionType.intervals,
          'Anaerobic capacity',
          8,
          '1 min',
          1,
          3,
          125,
          140,
          ftp,
          68,
          'Develops repeatable short power above VO2 intensity.',
          confidence,
          suitabilityScore: suitability('Anaerobic', 84).total),
      _interval(
          'Sprint',
          SessionType.intervals,
          'Neuromuscular sprint',
          8,
          '12 sec',
          0,
          4,
          150,
          200,
          ftp,
          52,
          'Develops acceleration and peak neuromuscular power.',
          confidence,
          suitabilityScore: suitability('Sprint', 78).total),
    ];
    final candidates = [recovery, endurance, durability, tempo, ...quality];
    return candidates
        .map((choice) => evaluated(
              choice,
              suitability(choice.family, _demandFor(choice.family)),
            ))
        .toList(growable: false);
  }

  List<UnplannedWorkoutChoice> select({
    required int readiness,
    required int ftp,
    required double form,
    required double rampRate,
    required bool hardSessionWithin48Hours,
    required AdaptationTarget weeklyIntent,
    Map<WorkoutFamily, double> capabilityGaps = const {},
    Map<WorkoutFamily, WorkoutResponseSnapshot> learnedResponses = const {},
    Map<WorkoutFamily, double> recoveryCosts = const {},
    int? availableMinutes,
    RideSetting rideSetting = RideSetting.flexible,
    bool hasIndoorTrainer = true,
    bool outdoorConditionsSafe = true,
  }) {
    final constrained = readiness < 45 || form < -20 || rampRate > 10;
    final qualityAllowed = readiness >= 60 &&
        form >= -15 &&
        rampRate <= 8 &&
        !hardSessionWithin48Hours;
    final moderateAllowed = readiness >= 50 &&
        form >= -20 &&
        rampRate <= 10 &&
        !hardSessionWithin48Hours;
    final visibleFamilies = constrained
        ? const {'Recovery', 'Endurance'}
        : !moderateAllowed
            ? const {'Endurance', 'Recovery', 'Durability'}
            : !qualityAllowed
                ? const {'Endurance', 'Tempo', 'Recovery', 'Durability'}
                : const {
                    'Endurance',
                    'Durability',
                    'Sweet spot',
                    'Threshold',
                    'VO2 max',
                    'Climbing strength',
                    'Anaerobic',
                    'Sprint',
                  };
    final eligible = evaluate(
      readiness: readiness,
      ftp: ftp,
      form: form,
      rampRate: rampRate,
      hardSessionWithin48Hours: hardSessionWithin48Hours,
      weeklyIntent: weeklyIntent,
      capabilityGaps: capabilityGaps,
      learnedResponses: learnedResponses,
      recoveryCosts: recoveryCosts,
      availableMinutes: availableMinutes,
      rideSetting: rideSetting,
      hasIndoorTrainer: hasIndoorTrainer,
      outdoorConditionsSafe: outdoorConditionsSafe,
    )
        .where((choice) =>
            choice.isEligible && visibleFamilies.contains(choice.family))
        .toList();
    eligible.sort((a, b) {
      final score = b.suitabilityScore.compareTo(a.suitabilityScore);
      return score != 0 ? score : a.family.compareTo(b.family);
    });
    if (eligible.isEmpty) return const [];
    return [eligible.first.asRecommended(), ...eligible.skip(1)];
  }
}

double _demandFor(String family) => switch (family) {
      'Recovery' => 35,
      'Endurance' => 52,
      'Durability' || 'Tempo' => 58,
      'Sweet spot' => 65,
      'Threshold' => 72,
      'VO2 max' => 80,
      'Climbing strength' => 68,
      'Anaerobic' => 84,
      'Sprint' => 78,
      _ => 50,
    };

double _intentBonus(String family, AdaptationTarget intent) {
  final matched = switch (intent) {
    AdaptationTarget.activeRecovery => family == 'Recovery',
    AdaptationTarget.aerobicEfficiency => family == 'Endurance',
    AdaptationTarget.aerobicDurability ||
    AdaptationTarget.fatigueResistance =>
      family == 'Durability',
    AdaptationTarget.muscularEndurance => family == 'Tempo' ||
        family == 'Sweet spot' ||
        family == 'Climbing strength',
    AdaptationTarget.lactateClearance ||
    AdaptationTarget.thresholdPower =>
      family == 'Threshold',
    AdaptationTarget.maximalAerobicPower => family == 'VO2 max',
    AdaptationTarget.anaerobicCapacity => family == 'Anaerobic',
    AdaptationTarget.neuromuscularPower => family == 'Sprint',
    AdaptationTarget.pedallingEconomy => family == 'Endurance',
    AdaptationTarget.raceSpecificity =>
      family == 'Threshold' || family == 'VO2 max',
  };
  return matched ? 10 : 0;
}

double _capabilityGapBonus(
  String family,
  Map<WorkoutFamily, double> capabilityGaps,
) {
  final workoutFamily = switch (family) {
    'Recovery' => WorkoutFamily.recovery,
    'Endurance' => WorkoutFamily.endurance,
    'Durability' => WorkoutFamily.longEndurance,
    'Tempo' => WorkoutFamily.tempo,
    'Sweet spot' => WorkoutFamily.sweetSpot,
    'Threshold' => WorkoutFamily.threshold,
    'VO2 max' => WorkoutFamily.vo2Max,
    'Climbing strength' => WorkoutFamily.climbingEndurance,
    'Anaerobic' => WorkoutFamily.anaerobic,
    'Sprint' => WorkoutFamily.sprint,
    _ => null,
  };
  if (workoutFamily == null) return 0;
  return (capabilityGaps[workoutFamily] ?? 0).clamp(0, 1) * 20;
}

WorkoutFamily? _familyFromLabel(String family) => switch (family) {
      'Recovery' => WorkoutFamily.recovery,
      'Endurance' => WorkoutFamily.endurance,
      'Durability' => WorkoutFamily.longEndurance,
      'Tempo' => WorkoutFamily.tempo,
      'Sweet spot' => WorkoutFamily.sweetSpot,
      'Threshold' => WorkoutFamily.threshold,
      'VO2 max' => WorkoutFamily.vo2Max,
      'Climbing strength' => WorkoutFamily.climbingEndurance,
      'Anaerobic' => WorkoutFamily.anaerobic,
      'Sprint' => WorkoutFamily.sprint,
      _ => null,
    };

double _historicalResponseScore(
  String family,
  Map<WorkoutFamily, WorkoutResponseSnapshot> responses,
  Map<WorkoutFamily, double> recoveryCosts,
) {
  final workoutFamily = _familyFromLabel(family);
  if (workoutFamily == null) return 0;
  final response = responses[workoutFamily];
  var score = 0.0;
  if (response != null && response.sampleCount >= 3) {
    if (response.completionRate >= .9 && response.averageLegFatigue <= 2.5) {
      score += 8;
    } else if (response.completionRate < .7) {
      score -= 15;
    }
    if (response.averageLoadRatio > 1.2 || response.averageLegFatigue >= 4) {
      score -= 12;
    }
  }
  final recoveryCost = recoveryCosts[workoutFamily];
  if (recoveryCost != null && recoveryCost > 60) {
    score -= ((recoveryCost - 60) * .4).clamp(0, 16);
  }
  return score;
}

UnplannedWorkoutChoice _steady(
        String family,
        SessionType type,
        String name,
        int minutes,
        int load,
        int low,
        int high,
        int ftp,
        String reason,
        double confidence,
        double suitabilityScore,
        {bool recommended = false}) =>
    UnplannedWorkoutChoice(
      family: family,
      type: type,
      title: '$name · $minutes min',
      durationMinutes: minutes,
      targetLoad: load,
      prescription: low == 0
          ? 'Below ${(ftp * high / 100).round()} W · relaxed cadence'
          : '${(ftp * low / 100).round()}–${(ftp * high / 100).round()} W · steady Zone 2',
      reason: reason,
      confidence: confidence,
      suitabilityScore: suitabilityScore,
      recommended: recommended,
    );

UnplannedWorkoutChoice _interval(
        String family,
        SessionType type,
        String name,
        int reps,
        String workLabel,
        int workMinutes,
        int recoveryMinutes,
        int low,
        int high,
        int ftp,
        int load,
        String reason,
        double confidence,
        {required double suitabilityScore,
        String detail = ''}) =>
    UnplannedWorkoutChoice(
      family: family,
      type: type,
      title: '$name · $reps × $workLabel',
      durationMinutes: workMinutes == 0
          ? 50
          : 25 + reps * workMinutes + (reps - 1) * recoveryMinutes,
      targetLoad: load,
      prescription:
          '$reps × $workLabel at ${(ftp * low / 100).round()}–${(ftp * high / 100).round()} W$detail, $recoveryMinutes min easy',
      reason: reason,
      confidence: confidence,
      suitabilityScore: suitabilityScore,
    );
