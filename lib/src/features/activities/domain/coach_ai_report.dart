import 'package:cycle_ready/src/features/activities/domain/advanced_ride_metrics.dart';
import 'package:cycle_ready/src/features/activities/domain/post_ride_debrief.dart';
import 'package:cycle_ready/src/features/activities/domain/power_breakthrough.dart';
import 'package:cycle_ready/src/features/activities/domain/ride_analysis.dart';
import 'package:cycle_ready/src/features/activities/domain/workout_execution.dart';

enum CoachConfidence { high, medium, low }

class CoachVerdict {
  const CoachVerdict({
    required this.sessionQuality,
    required this.trainingBenefit,
    required this.recoveryDemand,
    required this.tomorrow,
    required this.keyFocus,
  });

  final String sessionQuality;
  final String trainingBenefit;
  final String recoveryDemand;
  final String tomorrow;
  final String keyFocus;
}

class CoachAiReport {
  const CoachAiReport({
    required this.summary,
    required this.objective,
    required this.executionScore,
    required this.execution,
    required this.power,
    required this.heartRate,
    required this.cadence,
    required this.fatigue,
    required this.adaptation,
    required this.comparison,
    required this.recovery,
    required this.doneWell,
    required this.improvements,
    required this.verdict,
    required this.confidence,
    required this.confidenceReason,
  });

  final String summary;
  final String objective;
  final double executionScore;
  final String execution;
  final String power;
  final String heartRate;
  final String cadence;
  final String fatigue;
  final String adaptation;
  final String comparison;
  final String recovery;
  final List<String> doneWell;
  final List<String> improvements;
  final CoachVerdict verdict;
  final CoachConfidence confidence;
  final String confidenceReason;
}

CoachAiReport buildCoachAiReport({
  required DebriefRide ride,
  required Iterable<DebriefRide> history,
  required AdvancedRideMetrics advanced,
  required RideAnalysis analysis,
  required int ftp,
  required double weightKg,
  String? plannedType,
  int? plannedMinutes,
  int? plannedLoad,
  int? perceivedEffort,
  int? legFatigue,
  int? discomfort,
  int? enjoyment,
  List<PowerBreakthrough> breakthroughs = const [],
  WorkoutExecutionAnalysis? workoutExecution,
}) {
  final ifValue = analysis.intensityFactor;
  final inferredObjective = _objective(ifValue, analysis.powerZones);
  final titleObjective = inferWorkoutObjective(ride.title);
  final objective = plannedType != null
      ? _labelObjective(plannedType)
      : titleObjective ?? inferredObjective;
  final minutes = ride.durationSeconds / 60;
  final durationRatio = plannedMinutes == null || plannedMinutes <= 0
      ? null
      : minutes / plannedMinutes;
  final loadRatio =
      plannedLoad == null || plannedLoad <= 0 || ride.trainingLoad == null
          ? null
          : ride.trainingLoad! / plannedLoad;
  final vi = analysis.variabilityIndex;
  final drift = advanced.aerobicDecouplingPercent;
  var score = 8.5;
  if (durationRatio != null) score -= (durationRatio - 1).abs() * 4;
  if (loadRatio != null) score -= (loadRatio - 1).abs() * 2.5;
  if (vi != null && objective == 'Endurance' && vi > 1.12) score -= 1;
  if (drift != null && drift > 5) score -= 1;
  if (workoutExecution?.isReliable ?? false) {
    score = score * .65 + workoutExecution!.targetAccuracy * 10 * .35;
  }
  if ((discomfort ?? 0) >= 7) score -= 1.5;
  score = score.clamp(0, 10);

  final demanding = (ride.trainingLoad ?? 0) >= 80 || (ifValue ?? 0) >= .85;
  final efficient = drift != null && drift <= 5;
  final historyWindow = history
      .where((item) =>
          item.id != ride.id &&
          item.startedAt.isBefore(ride.startedAt) &&
          item.startedAt.isAfter(
            ride.startedAt.subtract(const Duration(days: 56)),
          ))
      .toList();
  final comparable = historyWindow
      .where((item) => item.efficiency != null)
      .map((item) => item.efficiency!)
      .toList();
  final efficiencyChange = ride.efficiency == null || comparable.isEmpty
      ? null
      : (ride.efficiency! /
                  (comparable.reduce((a, b) => a + b) / comparable.length) -
              1) *
          100;
  final objectiveAchieved = score >= 6.5;
  final dataFields = [
    ride.averagePower,
    ride.averageHeartRate,
    advanced.averageCadence,
    ride.trainingLoad,
    ifValue,
    drift,
  ].where((value) => value != null).length;
  final confidence = dataFields >= 5 && historyWindow.length >= 3
      ? CoachConfidence.high
      : dataFields >= 3
          ? CoachConfidence.medium
          : CoachConfidence.low;

  final power = ride.averagePower == null
      ? 'Power was not available, so I cannot judge pacing or muscular demand reliably. Use heart rate and perceived effort for this ride, and check that power recording is enabled next time.'
      : vi == null
          ? 'Power confirms useful work, but the stream is not complete enough to judge pacing variability. The training benefit is most likely $objective development.'
          : vi <= 1.08
              ? 'Power delivery was controlled and economical. That steadiness limits unnecessary surges and directs more of the work toward the intended $objective stimulus.'
              : 'Power was variable. Repeated surges increase carbohydrate cost and muscular fatigue; smooth the early efforts unless terrain or the workout specifically demands attacks.';
  final heart = ride.averageHeartRate == null
      ? 'Heart-rate data was unavailable, so cardiac strain and recovery cannot be judged. This lowers confidence rather than implying that the response was normal.'
      : drift == null
          ? 'Heart rate shows cardiovascular work, but there was not enough paired power data to assess drift. Judge recovery tomorrow using resting heart rate, sleep and how your legs feel.'
          : drift <= 3
              ? 'Heart rate stayed well coupled to power. That suggests good aerobic control and no obvious late-session cardiovascular strain.'
              : drift <= 5
                  ? 'Heart rate drift remained acceptable. The aerobic system coped, although fuelling and hydration still matter before repeating intensity.'
                  : 'Heart rate rose relative to power late in the ride. Heat, dehydration, under-fuelling, pacing or residual fatigue are the first things to check—not fitness alone.';
  final cadence = advanced.averageCadence == null
      ? 'Cadence was not recorded, so pedalling efficiency and cadence deterioration cannot be assessed.'
      : advanced.averageCadence! < 70
          ? 'Cadence was deliberately or habitually low. That increases muscular torque; keep it only when strength endurance is the goal, otherwise use a lighter gear to reduce leg fatigue.'
          : advanced.averageCadence! > 100
              ? 'Cadence was high, shifting demand toward the cardiovascular system. Keep the upper body relaxed so the extra leg speed remains economical.'
              : 'Cadence sat in an efficient general-purpose range. Continue prioritising smooth pressure through the pedal stroke as fatigue builds.';
  final fatigue = (discomfort ?? 0) >= 7
      ? 'Discomfort is the dominant signal. Do not force intensity tomorrow; monitor whether it settles and seek appropriate assessment if it persists or worsens.'
      : (legFatigue ?? 0) >= 8 || (perceivedEffort ?? 0) >= 9
          ? 'Your subjective response indicates substantial peripheral fatigue even if the headline data looks acceptable. Recovery should take priority over adding load.'
          : drift != null && drift > 5
              ? 'There are signs of late-session fatigue, but the cause is not certain. Review pacing, fluids, carbohydrate intake, heat and sleep before changing FTP.'
              : demanding
                  ? 'This created meaningful residual fatigue. Expect the legs to feel loaded and reassess readiness before the next quality session.'
                  : 'No strong fatigue warning is visible. Normal training can continue if morning readiness and leg feel agree.';
  final comparison = historyWindow.isEmpty
      ? 'This ride begins the personal comparison baseline. I will avoid claiming progress until comparable sessions exist.'
      : efficiencyChange == null
          ? 'There are ${historyWindow.length} recent rides, but not enough matched power and heart-rate data for a meaningful efficiency comparison.'
          : '${efficiencyChange.abs().toStringAsFixed(1)}% ${efficiencyChange >= 0 ? 'more' : 'less'} power per heartbeat than your recent baseline. ${efficiencyChange >= 0 ? 'That supports improving aerobic economy if repeated.' : 'Treat this as a fatigue or conditions signal unless it repeats across similar rides.'}';
  final protein = (weightKg.clamp(40, 150) * .3).round();
  final carbsLow = (weightKg.clamp(40, 150) * (demanding ? .9 : .6)).round();
  final carbsHigh = (weightKg.clamp(40, 150) * (demanding ? 1.2 : .9)).round();
  final recovery =
      'Within the next meal, target $carbsLow–$carbsHigh g carbohydrate and about $protein g protein. Replace fluid steadily, include sodium after heavy sweating, and prioritise a full night of sleep. ${demanding ? 'Allow roughly 24–36 hours before more intensity.' : 'Easy training tomorrow is reasonable if readiness remains stable.'}';
  final next = (discomfort ?? 0) >= 7
      ? 'Complete rest'
      : demanding || (legFatigue ?? 0) >= 8
          ? 'Recovery spin'
          : 'Easy endurance';
  final focus = drift != null && drift > 5
      ? 'Start slightly easier and fuel early to reduce late-session drift.'
      : vi != null && vi > 1.12
          ? 'Smooth the first half and reduce unnecessary power spikes.'
          : 'Repeat the same control and finish the final effort as strongly as the first.';

  return CoachAiReport(
    summary:
        '${objectiveAchieved ? 'You delivered the main $objective stimulus.' : 'The $objective goal was only partly achieved.'} ${efficient ? 'The effort stayed aerobically controlled.' : demanding ? 'It was productive, but it carried a meaningful recovery cost.' : 'It added useful work without excessive load.'} ${next == 'Easy endurance' ? 'You should feel capable of normal easy training tomorrow.' : 'Let recovery convert today’s work into fitness.'}',
    objective:
        '$objective — ${objectiveAchieved ? 'achieved' : 'partly achieved'}. ${plannedType != null ? 'This is judged against the workout recorded in your calendar.' : titleObjective != null ? 'CycleReady recognised this objective from the imported session name “${ride.title}” and checked it against the ride data.' : 'This is inferred from the available intensity and zone data.'}',
    executionScore: score,
    execution: workoutExecution != null
        ? '${score >= 8 ? 'Execution was strong.' : score >= 6 ? 'Execution was useful but not perfect.' : 'Execution needs attention.'} ${workoutExecution.summary} ${durationRatio == null ? '' : 'You completed ${(durationRatio * 100).round()}% of planned duration.'} ${loadRatio == null ? '' : 'The completed load was ${(loadRatio * 100).round()}% of target.'}'
        : '${score >= 8 ? 'Execution was strong.' : score >= 6 ? 'Execution was useful but not perfect.' : 'Execution needs attention.'} ${durationRatio == null ? 'No planned duration was available for compliance scoring.' : 'You completed ${(durationRatio * 100).round()}% of planned duration.'} ${loadRatio == null ? '' : 'The completed load was ${(loadRatio * 100).round()}% of target.'}',
    power: power,
    heartRate: heart,
    cadence: cadence,
    fatigue: fatigue,
    adaptation:
        '$objective primarily develops ${_adaptation(objective)}. ${objectiveAchieved ? 'Today provided the required stimulus; improvement comes from recovering and repeating it consistently.' : 'The stimulus was incomplete, so identify pacing, fatigue or fuelling as the limiter before making the workout harder.'}',
    comparison: comparison,
    recovery: recovery,
    doneWell: [
      if (breakthroughs.isNotEmpty)
        'Set rolling eight-week best power for ${breakthroughs.map((item) => item.label).join(', ')}.',
      objectiveAchieved
          ? 'Created the intended $objective stimulus.'
          : 'Completed useful training despite imperfect execution.',
      efficient
          ? 'Kept power and heart rate well coupled.'
          : 'Banked a measurable session for future comparison.',
      if ((enjoyment ?? 0) >= 8)
        'You rated the session highly for enjoyment, which supports repeatable training.',
      (vi ?? 1) <= 1.12
          ? 'Controlled power without excessive surging.'
          : 'Completed the session despite variable demands.',
    ],
    improvements: [
      focus,
      drift != null && drift > 5
          ? 'Review carbohydrate and fluid intake before blaming fitness.'
          : 'Keep fuelling proportional to session demand.',
      advanced.averageCadence == null
          ? 'Record cadence to assess pedalling under fatigue.'
          : 'Keep cadence controlled as fatigue rises.',
    ],
    verdict: CoachVerdict(
      sessionQuality: score >= 8
          ? 'Excellent'
          : score >= 6.5
              ? 'Good'
              : score >= 5
                  ? 'Mixed'
                  : 'Poor',
      trainingBenefit:
          objectiveAchieved ? (demanding ? 'High' : 'Moderate') : 'Low',
      recoveryDemand: (discomfort ?? 0) >= 7
          ? 'Very high'
          : demanding
              ? 'High'
              : (ride.trainingLoad ?? 0) >= 40
                  ? 'Moderate'
                  : 'Low',
      tomorrow: next,
      keyFocus: focus,
    ),
    confidence: confidence,
    confidenceReason:
        '${confidence.name[0].toUpperCase()}${confidence.name.substring(1)} confidence: $dataFields of 6 key data signals were available${historyWindow.isEmpty ? ', with no historical comparison yet.' : ' and ${historyWindow.length} recent rides supported context.'}',
  );
}

String? inferWorkoutObjective(String? title) {
  final value = title?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  if (_containsAny(value, ['recovery', 'rec ride', 'easy spin', 'rest day'])) {
    return 'Recovery';
  }
  if (_containsAny(value, ['sweet spot', 'sweetspot', 'sst'])) {
    return 'Sweet Spot';
  }
  if (_containsAny(value, ['threshold', 'ftp', 'over under', 'over-under'])) {
    return 'Threshold';
  }
  if (_containsAny(value, ['vo2', 'vo₂', 'max aerobic', 'map'])) {
    return 'VO2 Max';
  }
  if (_containsAny(value, ['anaerobic', 'sprint', 'neuromuscular'])) {
    return 'Anaerobic';
  }
  if (_containsAny(value, ['tempo', 'zone 3', 'z3'])) return 'Tempo';
  if (_containsAny(value, ['endurance', 'zone 2', 'z2', 'base', 'long ride'])) {
    return 'Endurance';
  }
  if (RegExp(r'(^|\D)(10|15|20|30)s(ec)?(\D|$)').hasMatch(value)) {
    return 'Anaerobic';
  }
  return null;
}

bool _containsAny(String value, Iterable<String> terms) =>
    terms.any(value.contains);

String _objective(double? intensity, List<ZoneDuration> zones) {
  if (intensity != null) {
    if (intensity < .55) return 'Recovery';
    if (intensity < .75) return 'Endurance';
    if (intensity < .88) return 'Tempo';
    if (intensity < .95) return 'Sweet Spot';
    if (intensity < 1.05) return 'Threshold';
    if (intensity < 1.2) return 'VO2 Max';
    return 'Anaerobic';
  }
  if (zones.isNotEmpty) {
    final dominant = [...zones]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return switch (dominant.first.name) {
      'Z1' => 'Recovery',
      'Z2' => 'Endurance',
      'Z3' => 'Tempo',
      'Z4' => 'Threshold',
      'Z5' => 'VO2 Max',
      _ => 'Anaerobic',
    };
  }
  return 'Endurance';
}

String _labelObjective(String type) => switch (type) {
      'recovery' => 'Recovery',
      'endurance' => 'Endurance',
      'tempo' => 'Tempo',
      'intervals' => 'Threshold / VO2 Max',
      'rest' => 'Recovery',
      _ => 'Endurance',
    };

String _adaptation(String objective) => switch (objective) {
      'Recovery' => 'circulation and recovery without meaningful new fatigue',
      'Endurance' => 'aerobic base, fat oxidation and durability',
      'Tempo' => 'muscular endurance and sustainable aerobic power',
      'Sweet Spot' => 'threshold durability and lactate clearance',
      'Threshold' => 'FTP and lactate clearance',
      'Threshold / VO2 Max' => 'high aerobic power and threshold capacity',
      'VO2 Max' => 'maximal aerobic power and oxygen utilisation',
      'Anaerobic' => 'anaerobic capacity and neuromuscular recruitment',
      _ => 'cycling-specific aerobic fitness',
    };
