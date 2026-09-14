import 'package:cycle_ready/src/features/coaching/domain/unplanned_workout_choices.dart';

enum WorkoutBrowserDuration {
  any,
  upTo45Minutes,
  from46To75Minutes,
  over75Minutes
}

class WorkoutBrowserState {
  const WorkoutBrowserState({
    required this.candidates,
    this.family,
    this.duration = WorkoutBrowserDuration.any,
  });

  final List<UnplannedWorkoutChoice> candidates;
  final String? family;
  final WorkoutBrowserDuration duration;

  Set<String> get families =>
      candidates.map((candidate) => candidate.family).toSet();

  List<UnplannedWorkoutChoice> get visibleCandidates => candidates
      .where((candidate) => family == null || candidate.family == family)
      .where((candidate) => switch (duration) {
            WorkoutBrowserDuration.any => true,
            WorkoutBrowserDuration.upTo45Minutes =>
              candidate.durationMinutes <= 45,
            WorkoutBrowserDuration.from46To75Minutes =>
              candidate.durationMinutes >= 46 &&
                  candidate.durationMinutes <= 75,
            WorkoutBrowserDuration.over75Minutes =>
              candidate.durationMinutes > 75,
          })
      .toList(growable: false);

  WorkoutBrowserState copyWith({
    String? family,
    bool clearFamily = false,
    WorkoutBrowserDuration? duration,
  }) =>
      WorkoutBrowserState(
        candidates: candidates,
        family: clearFamily ? null : family ?? this.family,
        duration: duration ?? this.duration,
      );
}

/// Holds presentation filters without weakening domain safety decisions.
/// Rejected candidates remain visible so the athlete can see why they cannot
/// be selected, but [select] will never return one.
class WorkoutBrowserController {
  WorkoutBrowserController(List<UnplannedWorkoutChoice> candidates)
      : _state = WorkoutBrowserState(
          candidates: List.unmodifiable(candidates),
        );

  WorkoutBrowserState _state;
  WorkoutBrowserState get state => _state;

  void filterByFamily(String? family) {
    _state = family == null
        ? _state.copyWith(clearFamily: true)
        : _state.copyWith(family: family);
  }

  void filterByDuration(WorkoutBrowserDuration duration) {
    _state = _state.copyWith(duration: duration);
  }

  UnplannedWorkoutChoice? select(UnplannedWorkoutChoice candidate) {
    if (!_state.candidates.contains(candidate) || !candidate.isEligible) {
      return null;
    }
    return candidate;
  }
}
