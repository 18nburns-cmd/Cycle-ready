import 'package:cycle_ready/src/features/coaching/domain/daily_coaching.dart';
import 'package:cycle_ready/src/features/coaching/domain/athlete_learning.dart';
import 'package:cycle_ready/src/features/coaching/domain/unplanned_workout_choices.dart';
import 'package:cycle_ready/src/features/coaching/domain/workout_catalogue.dart';
import 'package:cycle_ready/src/features/coaching/domain/training_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = UnplannedWorkoutSelectionService();

  test('recovered athlete receives several structured choices', () {
    final choices = service.select(
      readiness: 78,
      ftp: 250,
      form: 2,
      rampRate: 4,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
    );
    expect(choices, hasLength(8));
    expect(choices.first.recommended, isTrue);
    expect(
        choices.map((choice) => choice.family),
        containsAll([
          'Sweet spot',
          'Threshold',
          'VO2 max',
          'Climbing strength',
          'Anaerobic',
          'Sprint'
        ]));
    expect(
        choices.map((choice) => choice.prescription), everyElement(isNotEmpty));
  });

  test('poor recovery offers safe choices without hard work', () {
    final choices = service.select(
      readiness: 38,
      ftp: 250,
      form: -22,
      rampRate: 4,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
    );
    expect(choices, hasLength(2));
    expect(choices.first.type, SessionType.recovery);
    expect(
        choices,
        isNot(contains(predicate<UnplannedWorkoutChoice>(
          (choice) =>
              choice.type == SessionType.tempo ||
              choice.type == SessionType.intervals,
        ))));
  });

  test('recent hard work removes another quality choice', () {
    final choices = service.select(
      readiness: 82,
      ftp: 250,
      form: 5,
      rampRate: 3,
      hardSessionWithin48Hours: true,
      weeklyIntent: AdaptationTarget.thresholdPower,
    );
    expect(choices.any((choice) => choice.type == SessionType.tempo), isFalse);
  });

  test('moderate readiness offers tempo but withholds high intensity', () {
    final choices = service.select(
        readiness: 54,
        ftp: 250,
        form: -8,
        rampRate: 6,
        hardSessionWithin48Hours: false,
        weeklyIntent: AdaptationTarget.muscularEndurance);
    expect(choices.map((choice) => choice.family), contains('Tempo'));
    expect(choices.map((choice) => choice.family), isNot(contains('VO2 max')));
    expect(choices.every((choice) => choice.confidence >= .55), isTrue);
  });

  test('best fit is ranked from evidence rather than the calendar date', () {
    final choices = service.select(
      readiness: 80,
      ftp: 250,
      form: 4,
      rampRate: 3,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.maximalAerobicPower,
    );
    final qualityAlternatives = choices
        .where((choice) =>
            choice.type == SessionType.tempo ||
            choice.type == SessionType.intervals)
        .toList();

    expect(choices.first.recommended, isTrue);
    expect(
      choices.first.suitabilityScore,
      qualityAlternatives
          .map((choice) => choice.suitabilityScore)
          .reduce((a, b) => a > b ? a : b),
    );
  });

  test('measured capability gap influences the safe best fit', () {
    final choices = service.select(
      readiness: 75,
      ftp: 250,
      form: 3,
      rampRate: 3,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.muscularEndurance,
      capabilityGaps: const {WorkoutFamily.threshold: 1},
    );

    expect(choices.first.family, 'Threshold');
  });

  test('repeated failure and high recovery cost lower family suitability', () {
    final choices = service.select(
      readiness: 75,
      ftp: 250,
      form: 3,
      rampRate: 3,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
      learnedResponses: const {
        WorkoutFamily.threshold: WorkoutResponseSnapshot(
          sampleCount: 5,
          completionRate: .5,
          averageLoadRatio: 1.25,
          averageLegFatigue: 4.2,
        ),
      },
      recoveryCosts: const {WorkoutFamily.threshold: 85},
    );

    expect(choices.first.family, isNot('Threshold'));
    expect(
      choices
          .firstWhere((choice) => choice.family == 'Threshold')
          .suitabilityScore,
      lessThan(choices.first.suitabilityScore),
    );
  });

  test('time and ride setting constraints are applied before ranking', () {
    final shortChoices = service.select(
      readiness: 75,
      ftp: 250,
      form: 3,
      rampRate: 3,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
      availableMinutes: 55,
    );
    final unavailableIndoor = service.select(
      readiness: 75,
      ftp: 250,
      form: 3,
      rampRate: 3,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
      rideSetting: RideSetting.indoor,
      hasIndoorTrainer: false,
    );

    expect(
        shortChoices.every((choice) => choice.durationMinutes <= 55), isTrue);
    expect(unavailableIndoor, isEmpty);
  });

  test('every evaluated candidate explains its score and rejection', () {
    final evaluations = service.evaluate(
      readiness: 42,
      ftp: 250,
      form: -8,
      rampRate: 4,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.thresholdPower,
      availableMinutes: 45,
    );

    expect(evaluations, hasLength(10));
    expect(
      evaluations.every((choice) =>
          choice.scoreComponents.keys.toSet().containsAll(const [
            'readiness fit',
            'form',
            'ramp rate',
            'training-block intent',
            'capability gap',
            'historical response',
          ]) &&
          choice.confidence >= .55),
      isTrue,
    );
    final threshold =
        evaluations.firstWhere((choice) => choice.family == 'Threshold');
    expect(threshold.isEligible, isFalse);
    expect(threshold.rejectionReasons, isNotEmpty);
    expect(
      evaluations
          .firstWhere((choice) => choice.family == 'Recovery')
          .isEligible,
      isTrue,
    );
  });

  test('missing optional evidence still produces deterministic ranking', () {
    List<String> rank() => service
        .select(
          readiness: 70,
          ftp: 250,
          form: 0,
          rampRate: 4,
          hardSessionWithin48Hours: false,
          weeklyIntent: AdaptationTarget.pedallingEconomy,
        )
        .map((choice) => choice.family)
        .toList();

    expect(rank(), rank());
  });

  test('unsafe context rejects every candidate with an explicit reason', () {
    final evaluations = service.evaluate(
      readiness: 75,
      ftp: 250,
      form: 0,
      rampRate: 4,
      hardSessionWithin48Hours: false,
      weeklyIntent: AdaptationTarget.aerobicEfficiency,
      rideSetting: RideSetting.outdoor,
      outdoorConditionsSafe: false,
      hasIndoorTrainer: false,
    );

    expect(evaluations.every((choice) => !choice.isEligible), isTrue);
    expect(
      evaluations.every((choice) => choice.rejectionReasons.any(
            (reason) => reason.contains('Outdoor conditions are unsafe'),
          )),
      isTrue,
    );
  });
}
