import 'package:cycle_ready/src/features/coaching/domain/adaptive_plan.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = AdaptivePlanGenerator();

  test('FTP goal creates structured FTP work and a long ride', () {
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 200,
      currentWeeklyLoad: 300,
      readiness: 75,
    );

    expect(plan, isNotEmpty);
    /* Legacy title assertion retained below for historical context. The
       production title is now deliberately normalised after duration fitting.
    expect(plan.any((item) => item.title.contains('4 × 8')), isTrue);
    */
    expect(plan.any((item) => item.title == 'Threshold · 4 × 8 min'), isTrue);
    expect(
      plan.any((item) =>
          item.day.weekday == DateTime.saturday &&
          item.title.startsWith('Endurance ·')),
      isTrue,
    );
    expect(
        plan
            .firstWhere((item) => item.type == SessionType.intervals)
            .prescription,
        contains('200–210 W'));
  });

  test('low readiness produces recovery work', () {
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.generalFitness,
      daysPerWeek: 3,
      longRideWeekday: DateTime.sunday,
      ftp: 200,
      currentWeeklyLoad: 250,
      readiness: 30,
    );
    expect(plan.every((item) => item.type == SessionType.recovery), isTrue);
  });

  test('never schedules dates before requested start', () {
    final start = DateTime(2026, 7, 29);
    final plan = generator.generate(
      start: start,
      goal: TrainingGoal.endurance,
      daysPerWeek: 5,
      longRideWeekday: DateTime.saturday,
      ftp: 200,
      currentWeeklyLoad: 300,
      readiness: 70,
    );
    expect(plan.every((item) => !item.day.isBefore(start)), isTrue);
  });

  test('high fatigue and ramp rate reduce the plan to recovery work', () {
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 420,
      readiness: 80,
      form: -28,
      rampRate: 11,
    );

    expect(plan.every((item) => item.type == SessionType.recovery), isTrue);
  });

  test('a demanding previous day prevents another hard session', () {
    final protectedDay = DateTime(2026, 7, 28);
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 300,
      readiness: 80,
      avoidHardDays: {protectedDay},
    );

    final adjusted = plan.firstWhere((item) => item.day == protectedDay);
    expect(adjusted.type, SessionType.endurance);
    expect(adjusted.title, startsWith('Endurance ·'));
    expect(adjusted.prescription, contains('intensity reduced'));
  });

  test('repeated missed sessions ease the first workout back', () {
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 300,
      readiness: 80,
      missedSessions: 2,
    );

    expect(plan.first.title, startsWith('Endurance ·'));
    expect(plan.first.prescription, contains('intensity reduced'));
    expect(plan.first.type, SessionType.endurance);
  });

  test('post-ride discomfort forces the protected day to recovery', () {
    final protectedDay = DateTime(2026, 7, 28);
    final plan = generator.generate(
      start: DateTime(2026, 7, 27),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 300,
      readiness: 80,
      recoveryDays: {protectedDay},
    );

    final protected = plan.firstWhere((item) => item.day == protectedDay);
    expect(protected.type, SessionType.recovery);
    expect(protected.prescription, contains('post-ride feedback'));
  });

  test('event taper cuts volume and retains a short opener', () {
    final plan = generator.generate(
      start: DateTime(2026, 10, 17),
      goal: TrainingGoal.event,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 400,
      readiness: 80,
      eventDate: DateTime(2026, 10, 24),
      eventLongRideMinutes: 240,
      horizonDays: 14,
    );
    expect(
      plan.any((item) =>
          item.type == SessionType.tempo && item.title.startsWith('Tempo')),
      isTrue,
    );
    expect(
      plan
          .where((item) => !item.day.isAfter(DateTime(2026, 10, 24)))
          .every((item) => item.durationMinutes <= 75),
      isTrue,
    );
  });

  test('event long rides respect available time', () {
    final plan = generator.generate(
      start: DateTime(2026, 9, 21),
      goal: TrainingGoal.event,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 500,
      readiness: 80,
      eventDate: DateTime(2026, 10, 24),
      eventLongRideMinutes: 120,
      horizonDays: 14,
    );
    expect(plan.every((item) => item.durationMinutes <= 120), isTrue);
  });

  test('availability controls day, duration, time and ride setting', () {
    final plan = generator.generate(
      start: DateTime(2026, 8, 24),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 300,
      readiness: 80,
      availability: const [
        CyclingAvailability(
          weekday: DateTime.wednesday,
          enabled: true,
          startMinutes: 17 * 60 + 30,
          durationMinutes: 45,
          setting: RideSetting.indoor,
        ),
      ],
    );

    expect(plan, isNotEmpty);
    expect(plan.every((item) => item.day.weekday == DateTime.wednesday), isTrue);
    expect(plan.every((item) => item.durationMinutes <= 45), isTrue);
    expect(plan.every((item) => item.startMinutes == 17 * 60 + 30), isTrue);
    expect(plan.every((item) => item.setting == RideSetting.indoor), isTrue);
    expect(plan.first.reason, contains('45-minute indoor window'));
    expect(plan.first.reason.length, greaterThan(350));
    expect(plan.first.reason, contains('sustainable power and FTP'));
    expect(plan.first.reason, contains('readiness 80'));
    expect(plan.first.title, contains('min'));
  });

  test('four-week block progresses before a recovery week', () {
    final plan = generator.generate(
      start: DateTime(2026, 8, 24),
      goal: TrainingGoal.endurance,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 400,
      readiness: 80,
    );
    final weekThree = plan.where((item) =>
        !item.day.isBefore(DateTime(2026, 9, 7)) &&
        item.day.isBefore(DateTime(2026, 9, 14)));
    final recoveryWeek = plan.where(
        (item) => !item.day.isBefore(DateTime(2026, 9, 14)));
    expect(weekThree, isNotEmpty);
    expect(recoveryWeek, isNotEmpty);
    expect(recoveryWeek.every((item) => item.type == SessionType.recovery),
        isTrue);
    expect(recoveryWeek.first.reason, contains('recovery week'));
    expect(recoveryWeek.first.title, startsWith('Recovery ·'));
  });

  test('FTP quality sessions progress their interval structure', () {
    final plan = generator.generate(
      start: DateTime(2026, 8, 24),
      goal: TrainingGoal.ftp,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 600,
      readiness: 85,
      horizonDays: 21,
    );
    final titles = plan
        .where((item) => item.type == SessionType.intervals)
        .map((item) => item.title)
        .toList();
    expect(titles, contains('Threshold · 4 × 6 min'));
    expect(titles, contains('Threshold · 4 × 8 min'));
    expect(titles, contains('Threshold · 3 × 12 min'));
  });

  test('calendar dates stay at midnight across daylight-saving changes', () {
    final plan = generator.generate(
      start: DateTime(2026, 10, 17),
      goal: TrainingGoal.generalFitness,
      daysPerWeek: 4,
      longRideWeekday: DateTime.saturday,
      ftp: 250,
      currentWeeklyLoad: 400,
      readiness: 80,
      horizonDays: 21,
    );
    expect(plan.every((item) => item.day.hour == 0), isTrue);
  });
}
