import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const library = PhaseAwareWorkoutLibrary();

  test('catalogue exposes more than 200 generated workout combinations', () {
    expect(PhaseAwareWorkoutLibrary.generatedWorkoutCount, greaterThan(200));
  });

  test('FTP build progresses threshold work across the block', () {
    final sessions = List.generate(
      3,
      (week) => library.select(
        goal: WorkoutLibraryGoal.ftp,
        phase: WorkoutLibraryPhase.build,
        requestedType: SessionType.intervals,
        blockWeek: week,
        ftp: 250,
        longRide: false,
      ),
    );
    expect(sessions.map((item) => item.title), [
      'Threshold · 4 × 6 min',
      'Threshold · 4 × 8 min',
      'Threshold · 3 × 12 min',
    ]);
    expect(sessions.last.targetLoad, greaterThan(sessions.first.targetLoad));
    expect(sessions.first.prescription, contains('250–263 W'));
  });

  test('specific phase selects VO2 work instead of generic threshold', () {
    final session = library.select(
      goal: WorkoutLibraryGoal.event,
      phase: WorkoutLibraryPhase.specific,
      requestedType: SessionType.intervals,
      blockWeek: 1,
      ftp: 300,
      longRide: false,
    );
    expect(session.title, startsWith('VO2 max'));
    expect(session.adaptation, contains('maximal aerobic power'));
  });

  test('recovery phase always overrides requested intensity', () {
    final session = library.select(
      goal: WorkoutLibraryGoal.ftp,
      phase: WorkoutLibraryPhase.recovery,
      requestedType: SessionType.intervals,
      blockWeek: 2,
      ftp: 250,
      longRide: false,
    );
    expect(session.type, SessionType.recovery);
    expect(session.title, startsWith('Recovery spin'));
  });
}
