import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_progress.dart';
import 'package:cycle_ready/src/features/readiness/domain/readiness_result.dart';
import 'package:cycle_ready/src/features/readiness/domain/recovery_input.dart';
import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';

enum CoachTone { celebrate, steady, recover }

class OfflineCoachReport {
  const OfflineCoachReport({
    required this.headline,
    required this.message,
    required this.tone,
    required this.wins,
    required this.focus,
    required this.tonight,
    required this.tomorrow,
    required this.dataNotes,
  });

  final String headline;
  final String message;
  final CoachTone tone;
  final List<String> wins;
  final List<String> focus;
  final List<String> tonight;
  final String tomorrow;
  final List<String> dataNotes;
}

class OfflineCoachEngine {
  const OfflineCoachEngine();

  OfflineCoachReport build({
    required ReadinessResult readiness,
    required RecoveryInput recovery,
    required TrainingMetrics training,
    required NutritionProgress nutrition,
    required int rideCount,
    required int rideMinutes,
    required double completedLoad,
    int strengthSessionCount = 0,
    int strengthMinutes = 0,
    PerformanceMomentum? performanceMomentum,
  }) {
    final trained = rideMinutes > 0 || strengthMinutes > 0;
    final sleepHours = recovery.sleepMinutes / 60;
    final proteinFraction = _fraction(
      nutrition.consumed.proteinGrams,
      nutrition.target.proteinGrams,
    );
    final carbohydrateFraction = _fraction(
      nutrition.consumed.carbohydrateGrams,
      nutrition.target.carbohydrateGrams,
    );
    final waterFraction = _fraction(
      nutrition.consumed.waterMillilitres.toDouble(),
      nutrition.target.waterMillilitres.toDouble(),
    );
    final wins = <String>[];
    final focus = <String>[];
    final tonight = <String>[];
    final notes = <String>[];

    if (trained) {
      final sessions = <String>[
        if (rideCount > 0) rideCount == 1 ? '1 ride' : '$rideCount rides',
        if (strengthSessionCount > 0)
          strengthSessionCount == 1
              ? '1 strength session'
              : '$strengthSessionCount strength sessions',
      ];
      wins.add('You completed ${sessions.join(' and ')} totalling '
          '${rideMinutes + strengthMinutes} minutes and '
          '${completedLoad.round()} load.');
    } else {
      wins.add(
        readiness.score < 50
            ? 'You avoided forcing a hard session on a low-readiness day.'
            : 'You have kept some capacity in reserve for the next quality session.',
      );
    }
    if (readiness.score >= 67 &&
        (recovery.hasHealthData || recovery.hasCheckIn)) {
      wins.add('Your recovery signals supported training today.');
    }
    if (proteinFraction >= .9) {
      wins.add('Protein intake is on target for repair and adaptation.');
    }
    if (waterFraction >= .9) {
      wins.add('Hydration is close to or above today’s target.');
    }
    if (performanceMomentum?.status == PerformanceMomentumStatus.improving) {
      wins.add(
          'Your recent power curve is improving across comparable efforts.');
    }

    if (sleepHours < 7) {
      focus.add(
        'Sleep was ${sleepHours.toStringAsFixed(1)} hours; protect an earlier bedtime tonight.',
      );
    }
    if (training.form < -15) {
      focus
          .add('Accumulated fatigue is high relative to your current fitness.');
    }
    if (training.rampRate > 8) {
      focus.add(
          'Your training load is increasing quickly, so avoid adding intensity.');
    }
    if (proteinFraction < .8) {
      focus.add(
        '${nutrition.proteinRemaining.ceil().clamp(0, 999)} g protein remains.',
      );
    }
    if (trained && carbohydrateFraction < .8) {
      focus.add(
        '${nutrition.carbohydrateRemaining.ceil().clamp(0, 999)} g carbohydrate remains for refuelling.',
      );
    }
    if (waterFraction < .8) {
      focus.add(
        '${nutrition.waterRemaining.clamp(0, 9999)} ml water remains against today’s target.',
      );
    }
    if (performanceMomentum?.status == PerformanceMomentumStatus.mixed) {
      focus.add(
        'Your power profile is changing shape. Judge progress by the demands of your current training block, not one headline number.',
      );
    }
    if (performanceMomentum?.status == PerformanceMomentumStatus.declining) {
      focus.add(
        'Recent best power is below the previous four-week block. Check fatigue and whether you attempted comparable hard efforts before changing FTP.',
      );
    }
    if (focus.isEmpty) {
      focus.add(
          'No major recovery warning stands out in the data logged today.');
    }

    if (nutrition.waterRemaining > 0) {
      tonight.add(
        'Sip ${nutrition.waterRemaining.clamp(0, 1000)} ml more water rather than drinking it all at bedtime.',
      );
    }
    if (nutrition.proteinRemaining > 5) {
      tonight.add(
        'Include about ${nutrition.proteinRemaining.ceil().clamp(10, 40)} g protein in your evening food.',
      );
    }
    tonight.add(
      sleepHours < 7
          ? 'Start winding down 30–60 minutes earlier and aim for at least 8 hours in bed.'
          : 'Keep your normal sleep routine and give yourself enough time for 8 hours in bed.',
    );

    if (!recovery.hasHealthData) {
      notes.add(
          'Recovery uses saved check-in/default data because live health data is unavailable.');
    }
    if (!trained) {
      notes.add('No completed training has been recorded for today.');
    }
    if (nutrition.consumed.calories == 0) {
      notes.add(
          'No food has been logged today, so nutrition advice is provisional.');
    }
    if (performanceMomentum == null) {
      notes.add(
          'Power momentum needs matching efforts in both four-week periods.');
    }

    final tone = readiness.score < 45 || training.form < -20
        ? CoachTone.recover
        : trained
            ? CoachTone.celebrate
            : CoachTone.steady;
    final headline = switch (tone) {
      CoachTone.celebrate =>
        trained ? 'Work banked. Now absorb it.' : 'You are building momentum.',
      CoachTone.steady => 'Consistency beats heroics.',
      CoachTone.recover => 'Recovery is training too.',
    };
    final message = switch (tone) {
      CoachTone.celebrate =>
        'Good work today. The session only makes you fitter when you support it with food, fluid and sleep. Finish the day well and tomorrow starts stronger.',
      CoachTone.steady => trained
          ? 'Today does not need to be spectacular to move you forward. Complete the small recovery actions below and keep the longer trend heading in the right direction.'
          : 'No workout is recorded today. Use your recovery signals and check-in to decide whether to train, and remember that a deliberate rest day can still move the bigger plan forward.',
      CoachTone.recover =>
        'Backing off when the signals call for it is disciplined training, not lost training. Give your body room to adapt and you will return with more quality.',
    };

    return OfflineCoachReport(
      headline: headline,
      message: message,
      tone: tone,
      wins: wins,
      focus: focus,
      tonight: tonight,
      tomorrow: _tomorrow(readiness, training),
      dataNotes: notes,
    );
  }

  double _fraction(double consumed, double target) =>
      target <= 0 ? 0 : consumed / target;

  String _tomorrow(ReadinessResult readiness, TrainingMetrics training) {
    if (training.form < -20 || training.rampRate > 8 || readiness.score < 40) {
      return 'Plan a rest day or 30–40 minutes of very easy spinning. Reassess after sleep and your morning check-in.';
    }
    if (readiness.score < 60 || training.form < -8) {
      return 'Keep tomorrow aerobic and conversational. Add intensity only if the morning check-in improves.';
    }
    return 'Your current trend supports the planned session. Confirm it after tomorrow’s sleep and check-in rather than forcing today’s recommendation.';
  }
}
