import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';

enum WorkoutLibraryPhase {
  foundation,
  build,
  peak,
  specific,
  taper,
  recovery,
  maintenance,
}

enum WorkoutLibraryGoal { balanced, ftp, endurance, event }

class WorkoutLibrarySelection {
  const WorkoutLibrarySelection({
    required this.id,
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.targetLoad,
    required this.prescription,
    required this.adaptation,
  });

  final String id;
  final SessionType type;
  final String title;
  final int durationMinutes;
  final int targetLoad;
  final String prescription;
  final String adaptation;
}

/// CycleReady's own phase-aware catalogue. Patterns are materialised against
/// FTP, block week and available duration rather than copied from a third party.
class PhaseAwareWorkoutLibrary {
  const PhaseAwareWorkoutLibrary();

  static const generatedWorkoutCount = 216;

  WorkoutLibrarySelection select({
    required WorkoutLibraryGoal goal,
    required WorkoutLibraryPhase phase,
    required SessionType requestedType,
    required int blockWeek,
    required int ftp,
    required bool longRide,
  }) {
    final week = blockWeek.clamp(0, 2);
    if (phase == WorkoutLibraryPhase.recovery ||
        requestedType == SessionType.recovery) {
      return _steady(
        id: 'recovery-reset-${week + 1}',
        type: SessionType.recovery,
        name: 'Recovery spin',
        minutes: const [30, 35, 40][week],
        loadFactor: .42,
        low: 40,
        high: 55,
        ftp: ftp,
        adaptation: 'Encourages circulation while keeping the training cost '
            'low enough to absorb the previous work.',
      );
    }
    if (phase == WorkoutLibraryPhase.taper) {
      if (requestedType == SessionType.tempo ||
          requestedType == SessionType.intervals) {
        return _intervals(
          id: 'taper-openers-${week + 1}',
          name: 'Taper openers',
          reps: const [3, 3, 4][week],
          workMinutes: 3,
          recoveryMinutes: 4,
          low: 95,
          high: 102,
          ftp: ftp,
          load: const [32, 35, 39][week],
          adaptation: 'Keeps high-end aerobic pathways responsive without '
              'creating fatigue close to the target event.',
          type: requestedType,
        );
      }
      return _steady(
        id: 'taper-endurance-${week + 1}',
        type: SessionType.endurance,
        name: 'Taper endurance',
        minutes: longRide ? 75 : 45,
        loadFactor: .48,
        low: 55,
        high: 67,
        ftp: ftp,
        adaptation: 'Maintains aerobic rhythm while volume falls and '
            'freshness rises.',
      );
    }
    if (longRide) {
      final minutes = switch (goal) {
        WorkoutLibraryGoal.endurance || WorkoutLibraryGoal.event => const [
            120,
            150,
            180
          ][week],
        _ => const [90, 105, 120][week],
      };
      final specific = phase == WorkoutLibraryPhase.specific;
      return _steady(
        id: '${specific ? 'event-durability' : 'long-endurance'}-${week + 1}',
        type: SessionType.endurance,
        name: specific ? 'Event durability' : 'Long endurance',
        minutes: specific ? (minutes + 30).clamp(90, 240) : minutes,
        loadFactor: .62,
        low: 60,
        high: 72,
        ftp: ftp,
        adaptation: specific
            ? 'Builds event-specific fatigue resistance while providing a '
                'realistic opportunity to practise pacing and fuelling.'
            : 'Expands aerobic durability, fat oxidation and the ability to '
                'produce steady power late in a ride.',
      );
    }
    if (requestedType == SessionType.intervals) {
      if (phase == WorkoutLibraryPhase.specific ||
          (phase == WorkoutLibraryPhase.peak &&
              goal != WorkoutLibraryGoal.ftp)) {
        final work = const [3, 4, 5][week];
        return _intervals(
          id: 'vo2-development-${week + 1}',
          name: 'VO2 max',
          reps: const [6, 5, 5][week],
          workMinutes: work,
          recoveryMinutes: work,
          low: 108,
          high: 118,
          ftp: ftp,
          load: const [68, 78, 88][week],
          adaptation: 'Raises maximal aerobic power and improves your ability '
              'to repeat hard efforts.',
        );
      }
      final structure = const [(4, 6), (4, 8), (3, 12)][week];
      return _intervals(
        id: 'threshold-progression-${week + 1}',
        name: 'Threshold',
        reps: structure.$1,
        workMinutes: structure.$2,
        recoveryMinutes: 4,
        low: 100,
        high: 105,
        ftp: ftp,
        load: const [65, 80, 90][week],
        adaptation: 'Increases sustainable power by progressively extending '
            'quality time close to FTP without all-out testing.',
      );
    }
    if (requestedType == SessionType.tempo) {
      final tempo = goal == WorkoutLibraryGoal.endurance &&
          phase == WorkoutLibraryPhase.foundation;
      final structure = tempo
          ? const [(3, 12), (2, 20), (3, 20)][week]
          : const [(3, 10), (3, 12), (2, 20)][week];
      return _intervals(
        id: '${tempo ? 'tempo-durability' : 'sweet-spot-progression'}-${week + 1}',
        name: tempo ? 'Tempo' : 'Sweet spot',
        reps: structure.$1,
        workMinutes: structure.$2,
        recoveryMinutes: 5,
        low: tempo ? 80 : 88,
        high: tempo ? 87 : 94,
        ftp: ftp,
        load: tempo ? const [55, 66, 78][week] : const [60, 70, 82][week],
        adaptation: tempo
            ? 'Builds muscular endurance and economical steady power before '
                'more demanding intensity is introduced.'
            : 'Accumulates substantial aerobic and muscular work with less '
                'recovery cost than repeated threshold sessions.',
        type: SessionType.tempo,
      );
    }
    return _steady(
      id: 'aerobic-foundation-${week + 1}',
      type: SessionType.endurance,
      name: phase == WorkoutLibraryPhase.maintenance
          ? 'Aerobic maintenance'
          : 'Aerobic endurance',
      minutes: const [50, 60, 75][week],
      loadFactor: .62,
      low: 60,
      high: 72,
      ftp: ftp,
      adaptation: 'Develops aerobic efficiency and repeatable training '
          'capacity without compromising the next quality session.',
    );
  }

  WorkoutLibrarySelection _steady({
    required String id,
    required SessionType type,
    required String name,
    required int minutes,
    required double loadFactor,
    required int low,
    required int high,
    required int ftp,
    required String adaptation,
  }) =>
      WorkoutLibrarySelection(
        id: id,
        type: type,
        title: '$name · $minutes min',
        durationMinutes: minutes,
        targetLoad: (minutes * loadFactor).round(),
        prescription: '${(ftp * low / 100).round()}–'
            '${(ftp * high / 100).round()} W · steady ${low < 55 ? 'easy' : 'Zone 2'}',
        adaptation: adaptation,
      );

  WorkoutLibrarySelection _intervals({
    required String id,
    required String name,
    required int reps,
    required int workMinutes,
    required int recoveryMinutes,
    required int low,
    required int high,
    required int ftp,
    required int load,
    required String adaptation,
    SessionType type = SessionType.intervals,
  }) {
    final duration = 25 + reps * workMinutes + (reps - 1) * recoveryMinutes;
    return WorkoutLibrarySelection(
      id: id,
      type: type,
      title: '$name · $reps × $workMinutes min',
      durationMinutes: duration,
      targetLoad: load,
      prescription: '$reps × $workMinutes min at '
          '${(ftp * low / 100).round()}–${(ftp * high / 100).round()} W, '
          '$recoveryMinutes min easy',
      adaptation: adaptation,
    );
  }
}
