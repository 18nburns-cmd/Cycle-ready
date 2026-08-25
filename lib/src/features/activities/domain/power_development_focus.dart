import 'package:cycle_ready/src/features/activities/domain/power_curve.dart';

enum PowerDevelopmentArea { sprint, anaerobic, vo2Max, threshold, endurance }

class PowerDevelopmentFocus {
  const PowerDevelopmentFocus({
    required this.area,
    required this.relativeScore,
    required this.comparisonCount,
  });

  final PowerDevelopmentArea area;
  final double relativeScore;
  final int comparisonCount;

  String get label => switch (area) {
        PowerDevelopmentArea.sprint => 'sprint power',
        PowerDevelopmentArea.anaerobic => 'anaerobic repeatability',
        PowerDevelopmentArea.vo2Max => 'VO₂ max power',
        PowerDevelopmentArea.threshold => 'threshold power',
        PowerDevelopmentArea.endurance => 'aerobic durability',
      };
}

PowerDevelopmentFocus? identifyPowerDevelopmentFocus({
  required Iterable<PowerCurvePoint> curve,
  required int ftp,
}) {
  if (ftp <= 0) return null;
  const areas = [
    (area: PowerDevelopmentArea.sprint, seconds: 5, target: 4.5),
    (area: PowerDevelopmentArea.anaerobic, seconds: 60, target: 1.8),
    (area: PowerDevelopmentArea.vo2Max, seconds: 300, target: 1.15),
    (area: PowerDevelopmentArea.threshold, seconds: 1200, target: .95),
    (area: PowerDevelopmentArea.endurance, seconds: 3600, target: .80),
  ];
  final points = curve.toList();
  final scored = [
    for (final area in areas)
      if (points.any((point) => point.seconds == area.seconds))
        (
          area: area.area,
          score: points
                  .firstWhere((point) => point.seconds == area.seconds)
                  .watts /
              ftp /
              area.target,
        ),
  ];
  // Avoid prescribing to an apparent weakness from a sparse curve.
  if (scored.length < 3) return null;
  scored.sort((a, b) => a.score.compareTo(b.score));
  return PowerDevelopmentFocus(
    area: scored.first.area,
    relativeScore: scored.first.score,
    comparisonCount: scored.length,
  );
}
