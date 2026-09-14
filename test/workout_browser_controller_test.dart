import 'package:cycle_ready/src/features/coaching/application/workout_browser_controller.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/unplanned_workout_choices.dart';
import 'package:flutter_test/flutter_test.dart';

UnplannedWorkoutChoice choice(
  String family,
  int duration, {
  List<String> rejections = const [],
}) =>
    UnplannedWorkoutChoice(
      family: family,
      type: SessionType.endurance,
      title: family,
      durationMinutes: duration,
      targetLoad: 30,
      prescription: 'Structured work',
      reason: 'Evidence-based option',
      confidence: .8,
      suitabilityScore: 75,
      rejectionReasons: rejections,
    );

void main() {
  test('filters candidates by family and duration', () {
    final controller = WorkoutBrowserController([
      choice('Endurance', 40),
      choice('Endurance', 80),
      choice('Threshold', 60),
    ]);

    controller.filterByFamily('Endurance');
    controller.filterByDuration(WorkoutBrowserDuration.upTo45Minutes);

    expect(controller.state.visibleCandidates, hasLength(1));
    expect(controller.state.visibleCandidates.single.durationMinutes, 40);
    expect(controller.state.families, {'Endurance', 'Threshold'});
  });

  test('keeps rejected candidates visible but unavailable', () {
    final unsafe = choice(
      'Threshold',
      60,
      rejections: const ['Readiness does not support high intensity.'],
    );
    final controller = WorkoutBrowserController([unsafe]);

    expect(controller.state.visibleCandidates, contains(unsafe));
    expect(unsafe.isEligible, isFalse);
    expect(controller.select(unsafe), isNull);
  });

  test('returns an eligible candidate for selection', () {
    final safe = choice('Endurance', 60);
    final controller = WorkoutBrowserController([safe]);

    expect(controller.select(safe), same(safe));
  });
}
