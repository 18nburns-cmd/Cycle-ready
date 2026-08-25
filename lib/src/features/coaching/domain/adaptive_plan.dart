import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/event_periodisation.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_library.dart';

enum TrainingGoal { generalFitness, ftp, endurance, event }

class AdaptiveWorkout {
  const AdaptiveWorkout({
    required this.day,
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    required this.prescription,
    this.reason =
        'This session balances progression with your recent training and recovery.',
    this.setting = RideSetting.flexible,
    this.startMinutes = 18 * 60,
  });

  final DateTime day;
  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String prescription;
  final String reason;
  final RideSetting setting;
  final int startMinutes;
}

class AdaptivePlanGenerator {
  const AdaptivePlanGenerator();

  List<AdaptiveWorkout> generate({
    required DateTime start,
    required TrainingGoal goal,
    required int daysPerWeek,
    required int longRideWeekday,
    required int ftp,
    required double currentWeeklyLoad,
    required int readiness,
    double form = 0,
    double rampRate = 0,
    int missedSessions = 0,
    Set<DateTime> avoidHardDays = const {},
    Set<DateTime> recoveryDays = const {},
    DateTime? eventDate,
    int? eventLongRideMinutes,
    int horizonDays = 28,
    List<CyclingAvailability> availability = const [],
  }) {
    final count = daysPerWeek.clamp(2, 6);
    final enabledSlots = availability.where((slot) => slot.enabled).toList();
    final available = enabledSlots.isEmpty
        ? _trainingDays(count, longRideWeekday)
        : enabledSlots.map((slot) => slot.weekday).toSet();
    var loadCeiling = currentWeeklyLoad <= 0
        ? 300.0
        : currentWeeklyLoad * (readiness < 50 ? .9 : 1.05);
    if (form < -15 || rampRate > 8) loadCeiling *= .85;
    final result = <AdaptiveWorkout>[];
    var weeklyLoad = 0;
    var activeWeek = -1;

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = DateTime(start.year, start.month, start.day + offset);
      final weekIndex = offset ~/ 7;
      if (weekIndex != activeWeek) {
        activeWeek = weekIndex;
        weeklyLoad = 0;
      }
      if (!available.contains(day.weekday)) continue;
      final slot =
          enabledSlots.where((item) => item.weekday == day.weekday).firstOrNull;
      final isLong = day.weekday == longRideWeekday;
      final sequence = result.where(
          (item) => item.day.isAfter(day.subtract(const Duration(days: 7))));
      final hardRecently = sequence.any((item) =>
          item.type == SessionType.intervals || item.type == SessionType.tempo);
      final phase = goal == TrainingGoal.event && eventDate != null
          ? eventPhaseFor(day, eventDate)
          : null;
      final baseWorkout = _workout(
        day: day,
        goal: goal,
        ftp: ftp,
        isLong: isLong,
        hardRecently: hardRecently,
        recoveryWeek: weekIndex == 3,
        readiness: readiness,
        form: form,
        rampRate: rampRate,
        eventPhase: phase,
        eventLongRideMinutes: eventLongRideMinutes,
        forceRecovery: recoveryDays.any((value) => _sameDay(value, day)),
        avoidHard: avoidHardDays.any((value) => _sameDay(value, day)) ||
            (missedSessions >= 2 && result.isEmpty),
      );
      final workout = _progressSessionStructure(
        baseWorkout,
        goal: goal,
        blockWeek: weekIndex % 4,
        ftp: ftp,
        isLong: isLong,
        eventPhase: phase,
        eventLongRideMinutes: eventLongRideMinutes,
      );
      final explained = _withReason(
        workout,
        _planRationale(
          workout: workout,
          goal: goal,
          phase: phase,
          readiness: readiness,
          form: form,
          rampRate: rampRate,
          hardRecently: hardRecently,
          isLong: isLong,
          weekIndex: weekIndex,
        ),
      );
      final fitted = _withDisplayTitle(
        _fitToAvailability(explained, slot),
      );
      final weeklyCeiling = loadCeiling *
          switch (weekIndex % 4) {
            0 => .92,
            1 => 1.0,
            2 => 1.06,
            _ => .65,
          };
      if (weeklyLoad + fitted.targetLoad > weeklyCeiling && result.isNotEmpty) {
        result.add(_withDisplayTitle(_fitToAvailability(
          _recovery(day, ftp,
              reason:
                  'Your rolling load is already near this week\'s safe ceiling.'),
          slot,
        )));
        weeklyLoad += 15;
      } else {
        result.add(fitted);
        weeklyLoad += fitted.targetLoad;
      }
    }
    return result;
  }

  AdaptiveWorkout _progressSessionStructure(
    AdaptiveWorkout workout, {
    required TrainingGoal goal,
    required int blockWeek,
    required int ftp,
    required bool isLong,
    required EventPhase? eventPhase,
    required int? eventLongRideMinutes,
  }) {
    if (workout.type == SessionType.rest ||
        eventPhase == EventPhase.eventWeek) {
      return workout;
    }
    final phase = switch (eventPhase) {
      EventPhase.base => WorkoutLibraryPhase.foundation,
      EventPhase.build => WorkoutLibraryPhase.build,
      EventPhase.specific => WorkoutLibraryPhase.specific,
      EventPhase.taper => WorkoutLibraryPhase.taper,
      EventPhase.eventWeek => WorkoutLibraryPhase.peak,
      EventPhase.complete => WorkoutLibraryPhase.maintenance,
      null => switch (blockWeek) {
          0 => WorkoutLibraryPhase.foundation,
          1 => WorkoutLibraryPhase.build,
          2 => WorkoutLibraryPhase.peak,
          _ => WorkoutLibraryPhase.recovery,
        },
    };
    final selection = const PhaseAwareWorkoutLibrary().select(
      goal: switch (goal) {
        TrainingGoal.generalFitness => WorkoutLibraryGoal.balanced,
        TrainingGoal.ftp => WorkoutLibraryGoal.ftp,
        TrainingGoal.endurance => WorkoutLibraryGoal.endurance,
        TrainingGoal.event => WorkoutLibraryGoal.event,
      },
      phase: phase,
      requestedType: workout.type,
      blockWeek: blockWeek,
      ftp: ftp,
      longRide: isLong,
    );
    final duration =
        goal == TrainingGoal.event && isLong && eventLongRideMinutes != null
            ? selection.durationMinutes.clamp(60, eventLongRideMinutes).toInt()
            : selection.durationMinutes;
    final adjustmentNote = workout.prescription.contains('intensity reduced') ||
            workout.prescription.contains('post-ride feedback')
        ? ' · ${workout.prescription}'
        : '';
    return AdaptiveWorkout(
      day: workout.day,
      type: selection.type,
      title: selection.title,
      durationMinutes: duration,
      targetLoad: duration == selection.durationMinutes
          ? selection.targetLoad
          : (selection.targetLoad * duration / selection.durationMinutes)
              .round(),
      prescription: '${selection.prescription}$adjustmentNote',
      reason: '${workout.reason} ${selection.adaptation}',
      setting: workout.setting,
      startMinutes: workout.startMinutes,
    );
  }

  AdaptiveWorkout _withDisplayTitle(AdaptiveWorkout workout) {
    final interval = RegExp(r'(\d+)\D+(\d+)\s*min', caseSensitive: false)
        .firstMatch(workout.title);
    final structure = interval == null
        ? null
        : '${interval.group(1)} × ${interval.group(2)} min';
    final base = switch (workout.type) {
      SessionType.rest => 'Rest day',
      SessionType.recovery => 'Recovery',
      SessionType.endurance
          when workout.title.toLowerCase().contains('taper') =>
        'Taper endurance',
      SessionType.endurance
          when workout.title.toLowerCase().contains('event') =>
        'Event endurance',
      SessionType.endurance => 'Endurance',
      SessionType.tempo when workout.title.toLowerCase().contains('sweet') =>
        'Sweet spot',
      SessionType.tempo => 'Tempo',
      SessionType.intervals when workout.title.toLowerCase().contains('vo2') =>
        'VO2 max',
      SessionType.intervals => 'Threshold',
    };
    final title = workout.type == SessionType.rest
        ? base
        : structure == null
            ? '$base · ${workout.durationMinutes} min'
            : '$base · $structure';
    return AdaptiveWorkout(
      day: workout.day,
      type: workout.type,
      title: title,
      durationMinutes: workout.durationMinutes,
      targetLoad: workout.targetLoad,
      prescription: workout.prescription,
      reason: workout.reason,
      setting: workout.setting,
      startMinutes: workout.startMinutes,
    );
  }

  AdaptiveWorkout _withReason(AdaptiveWorkout workout, String reason) =>
      AdaptiveWorkout(
        day: workout.day,
        type: workout.type,
        title: workout.title,
        durationMinutes: workout.durationMinutes,
        targetLoad: workout.targetLoad,
        prescription: workout.prescription,
        reason: reason,
        setting: workout.setting,
        startMinutes: workout.startMinutes,
      );

  String _planRationale({
    required AdaptiveWorkout workout,
    required TrainingGoal goal,
    required EventPhase? phase,
    required int readiness,
    required double form,
    required double rampRate,
    required bool hardRecently,
    required bool isLong,
    required int weekIndex,
  }) {
    final goalText = switch (goal) {
      TrainingGoal.ftp => 'raise your sustainable power and FTP',
      TrainingGoal.endurance => 'improve your aerobic durability',
      TrainingGoal.event => 'prepare specifically for your target event',
      TrainingGoal.generalFitness =>
        'build balanced, repeatable cycling fitness',
    };
    final stimulus = switch (workout.type) {
      SessionType.intervals =>
        'The controlled high-intensity repetitions provide a strong power stimulus without requiring an unstructured all-out effort.',
      SessionType.tempo =>
        'The sustained sub-threshold work develops muscular endurance and the ability to hold useful power while keeping the recovery cost manageable.',
      SessionType.endurance when isLong =>
        'The extended steady riding develops fatigue resistance, fuelling practice and the aerobic durability needed later in the plan.',
      SessionType.endurance =>
        'This aerobic session adds productive volume, improves efficiency and supports harder training without creating excessive fatigue.',
      SessionType.recovery =>
        'Keeping the effort genuinely easy maintains movement and circulation while allowing recent training adaptations to consolidate.',
      SessionType.rest =>
        'Removing training stress here gives your body time to absorb the work already completed.',
    };
    final placement = hardRecently
        ? 'It follows recent quality work, so its intensity is deliberately controlled rather than stacking another demanding session too soon.'
        : workout.type == SessionType.intervals ||
                workout.type == SessionType.tempo
            ? 'It is placed here because there has not been another hard cycling session in the preceding training window, giving you a better chance of completing the efforts with quality.'
            : 'Its position maintains continuity between key sessions and prepares you for the next higher-quality workout.';
    final recovery = readiness < 50 || form < -15 || rampRate > 8
        ? 'Your current recovery/load signals are cautious (readiness $readiness, form ${form.round()}, ramp rate ${rampRate.toStringAsFixed(1)}), so the prescription has been reduced to avoid turning useful fatigue into overload.'
        : 'Your current readiness and load balance support this amount of work (readiness $readiness and form ${form.round()}) without exceeding the plan’s progression ceiling.';
    final blockStage = switch (weekIndex % 4) {
      0 => 'foundation week, establishing repeatable work before load rises',
      1 => 'build week, adding a measured progression from the opening week',
      2 => 'highest-load week, providing the strongest stimulus of this block',
      _ =>
        'recovery week, reducing load so the previous three weeks can be absorbed',
    };
    final phaseText = phase == null
        ? 'This is week ${weekIndex + 1} of the current four-week block: the $blockStage. It contributes directly to the goal to $goalText.'
        : 'This falls in the ${phase.name.replaceAll('eventWeek', 'event week')} phase, where the priority is to $goalText while matching the appropriate balance of fitness, specificity and freshness.';
    final original = workout.reason.startsWith('This session balances')
        ? ''
        : '${workout.reason.trim()} ';
    return '$original$phaseText $stimulus $placement $recovery '
        'Completing it at the prescribed intensity—not harder—creates the intended adaptation and leaves the following sessions achievable.';
  }

  AdaptiveWorkout _fitToAvailability(
    AdaptiveWorkout workout,
    CyclingAvailability? slot,
  ) {
    if (slot == null) return workout;
    final duration = workout.durationMinutes.clamp(20, slot.durationMinutes);
    final scale = duration / workout.durationMinutes;
    final settingLabel = switch (slot.setting) {
      RideSetting.indoor => 'Indoor',
      RideSetting.outdoor => 'Outdoor',
      RideSetting.flexible => 'Indoor or outdoor',
    };
    final coachingReason = workout.reason.startsWith('This session balances')
        ? switch (workout.type) {
            SessionType.intervals =>
              'A focused interval session develops the power needed for your goal while you are fresh enough to absorb it.',
            SessionType.tempo =>
              'Controlled quality work builds sustainable power without the recovery cost of an all-out session.',
            SessionType.endurance =>
              'Aerobic endurance builds durable cycling fitness and supports recovery between harder days.',
            SessionType.recovery =>
              'An easy spin promotes recovery without adding meaningful fatigue.',
            SessionType.rest =>
              'Rest protects adaptation and prepares you for the next productive session.',
          }
        : workout.reason;
    return AdaptiveWorkout(
      day: workout.day,
      type: slot.durationMinutes < 40 &&
              (workout.type == SessionType.intervals ||
                  workout.type == SessionType.tempo)
          ? SessionType.endurance
          : workout.type,
      title: workout.title,
      durationMinutes: duration,
      targetLoad: (workout.targetLoad * scale).round().clamp(10, 200),
      prescription: '$settingLabel · ${workout.prescription}',
      reason: '$coachingReason It fits your ${slot.durationMinutes}-minute '
          '${slot.setting.name} window.',
      setting: slot.setting,
      startMinutes: slot.startMinutes,
    );
  }

  Set<int> _trainingDays(int count, int longDay) {
    const preferred = [2, 4, 6, 7, 3, 5];
    final days = <int>{longDay};
    for (final day in preferred) {
      if (days.length >= count) break;
      if (day != longDay) days.add(day);
    }
    return days;
  }

  AdaptiveWorkout _workout({
    required DateTime day,
    required TrainingGoal goal,
    required int ftp,
    required bool isLong,
    required bool hardRecently,
    required bool recoveryWeek,
    required int readiness,
    required double form,
    required double rampRate,
    required EventPhase? eventPhase,
    required int? eventLongRideMinutes,
    required bool forceRecovery,
    required bool avoidHard,
  }) {
    if (forceRecovery) {
      return _recovery(
        day,
        ftp,
        reason: 'post-ride feedback has protected this recovery day',
      );
    }
    if (recoveryWeek || readiness < 40 || form < -25 || rampRate > 10) {
      return _recovery(day, ftp, reason: 'recovery signals reduced intensity');
    }
    if (eventPhase == EventPhase.taper || eventPhase == EventPhase.eventWeek) {
      if (!hardRecently && !isLong && eventPhase == EventPhase.taper) {
        return AdaptiveWorkout(
          day: day,
          type: SessionType.tempo,
          title: 'Taper opener · short controlled efforts',
          durationMinutes: 45,
          targetLoad: 35,
          prescription:
              '3 × 3 min at ${(ftp * .95).round()}–${(ftp * 1.02).round()} W · finish fresh, not fatigued',
        );
      }
      return AdaptiveWorkout(
        day: day,
        type: SessionType.endurance,
        title: 'Taper endurance · stay fresh',
        durationMinutes: isLong ? 75 : 40,
        targetLoad: isLong ? 38 : 22,
        prescription:
            '${(ftp * .58).round()}–${(ftp * .68).round()} W · reduce volume and keep normal cadence',
      );
    }
    if (avoidHard && !isLong) {
      return AdaptiveWorkout(
        day: day,
        type: SessionType.endurance,
        title: 'Adjusted aerobic endurance',
        durationMinutes: 50,
        targetLoad: 32,
        prescription:
            '${(ftp * .58).round()}â€“${(ftp * .68).round()} W Â· intensity reduced after recent training or missed sessions',
      );
    }
    if (isLong) {
      final desiredMinutes = eventPhase == EventPhase.specific
          ? 180
          : goal == TrainingGoal.endurance || goal == TrainingGoal.event
              ? 150
              : 120;
      final minutes = goal == TrainingGoal.event && eventLongRideMinutes != null
          ? desiredMinutes.clamp(60, eventLongRideMinutes).toInt()
          : desiredMinutes;
      return AdaptiveWorkout(
        day: day,
        type: SessionType.endurance,
        title: eventPhase == EventPhase.specific
            ? 'Event-specific long ride · fuel and pace'
            : 'Long endurance ride',
        durationMinutes: minutes,
        targetLoad: minutes == 180
            ? 110
            : minutes == 150
                ? 95
                : 75,
        prescription:
            '${(ftp * .60).round()}–${(ftp * .72).round()} W · steady Zone 2',
      );
    }
    if (!hardRecently && goal == TrainingGoal.ftp) {
      return AdaptiveWorkout(
        day: day,
        type: SessionType.intervals,
        title: 'FTP development · 4 × 8 min',
        durationMinutes: 70,
        targetLoad: 80,
        prescription:
            '4 × 8 min at ${(ftp * 1.00).round()}–${(ftp * 1.05).round()} W, 4 min easy',
      );
    }
    if (!hardRecently &&
        (goal == TrainingGoal.event || goal == TrainingGoal.generalFitness)) {
      return AdaptiveWorkout(
        day: day,
        type: SessionType.tempo,
        title: 'Sweet spot · 3 × 12 min',
        durationMinutes: 70,
        targetLoad: 70,
        prescription:
            '3 × 12 min at ${(ftp * .88).round()}–${(ftp * .94).round()} W, 5 min easy',
      );
    }
    return AdaptiveWorkout(
      day: day,
      type: SessionType.endurance,
      title: 'Aerobic endurance',
      durationMinutes: 60,
      targetLoad: 40,
      prescription:
          '${(ftp * .60).round()}–${(ftp * .72).round()} W · conversational effort',
    );
  }

  AdaptiveWorkout _recovery(DateTime day, int ftp, {String? reason}) =>
      AdaptiveWorkout(
        day: day,
        type: SessionType.recovery,
        title: 'Recovery spin',
        durationMinutes: 35,
        targetLoad: 15,
        prescription: 'Below ${(ftp * .55).round()} W · '
            '${reason ?? 'keep this genuinely easy'}',
      );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
