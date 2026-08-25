class IntervalsPlannedWorkout {
  const IntervalsPlannedWorkout({
    required this.externalId,
    required this.day,
    required this.name,
    required this.description,
    required this.durationSeconds,
  });

  final String externalId;
  final DateTime day;
  final String name;
  final String description;
  final int durationSeconds;
}

String intervalsWorkoutDescription({
  required String sessionType,
  required int durationMinutes,
}) {
  switch (sessionType) {
    case 'intervals':
      return 'Warm-up\n'
          '- 15m 60%\n\n'
          '4x\n'
          '- 8m 102%\n'
          '- 4m 50%\n\n'
          'Cool-down\n'
          '- 10m 55%';
    case 'tempo':
      return 'Warm-up\n'
          '- 15m 60%\n\n'
          '3x\n'
          '- 12m 91%\n'
          '- 5m 50%\n\n'
          'Cool-down\n'
          '- 10m 55%';
    case 'recovery':
      return '- ${durationMinutes}m 50%';
    case 'endurance':
    default:
      return '- ${durationMinutes}m 66%';
  }
}
