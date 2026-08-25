class CoachingEventGoal {
  const CoachingEventGoal({
    required this.name,
    required this.eventDate,
    required this.distanceKm,
    required this.elevationMetres,
    required this.priority,
    required this.target,
    required this.terrain,
    required this.availableDays,
    required this.longRideMinutes,
  });

  final String name;
  final DateTime eventDate;
  final double distanceKm;
  final int elevationMetres;
  final String priority;
  final String target;
  final String terrain;
  final int availableDays;
  final int longRideMinutes;
}
