enum EventPhase { base, build, specific, taper, eventWeek, complete }

class EventTrainingBlock {
  const EventTrainingBlock({
    required this.phase,
    required this.start,
    required this.end,
    required this.focus,
    required this.loadDirection,
  });

  final EventPhase phase;
  final DateTime start;
  final DateTime end;
  final String focus;
  final String loadDirection;
}

EventPhase eventPhaseFor(DateTime day, DateTime eventDate) {
  final days = DateTime(eventDate.year, eventDate.month, eventDate.day)
      .difference(DateTime(day.year, day.month, day.day))
      .inDays;
  if (days < 0) return EventPhase.complete;
  if (days <= 3) return EventPhase.eventWeek;
  if (days <= 10) return EventPhase.taper;
  if (days <= 35) return EventPhase.specific;
  if (days <= 77) return EventPhase.build;
  return EventPhase.base;
}

List<EventTrainingBlock> buildEventBlocks({
  required DateTime now,
  required DateTime eventDate,
}) {
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(eventDate.year, eventDate.month, eventDate.day);
  if (end.isBefore(start)) return const [];
  final blocks = <EventTrainingBlock>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    final phase = eventPhaseFor(cursor, end);
    var blockEnd = cursor;
    while (blockEnd.isBefore(end)) {
      final candidate = blockEnd.add(const Duration(days: 1));
      if (eventPhaseFor(candidate, end) != phase) break;
      blockEnd = candidate;
    }
    blocks.add(EventTrainingBlock(
      phase: phase,
      start: cursor,
      end: blockEnd,
      focus: eventPhaseFocus(phase),
      loadDirection: switch (phase) {
        EventPhase.base => 'Build gradually',
        EventPhase.build => 'Progress load',
        EventPhase.specific => 'Hold productive load',
        EventPhase.taper => 'Reduce 35–50%',
        EventPhase.eventWeek => 'Freshen and activate',
        EventPhase.complete => 'Recover and review',
      },
    ));
    cursor = blockEnd.add(const Duration(days: 1));
  }
  return blocks;
}

String eventPhaseFocus(EventPhase phase) => switch (phase) {
      EventPhase.base =>
        'Aerobic base, consistency, technique and sustainable strength.',
      EventPhase.build =>
        'Threshold development, longer rides and progressive climbing load.',
      EventPhase.specific =>
        'Event-duration durability, terrain-specific efforts, pacing and fuelling rehearsal.',
      EventPhase.taper =>
        'Reduce volume while retaining short quality efforts and normal cadence.',
      EventPhase.eventWeek =>
        'Arrive fresh, keep the legs responsive and finalise pacing and nutrition.',
      EventPhase.complete =>
        'Recover, review execution and choose the next goal.',
    };

String eventPhaseLabel(EventPhase phase) => switch (phase) {
      EventPhase.base => 'Base',
      EventPhase.build => 'Build',
      EventPhase.specific => 'Event specific',
      EventPhase.taper => 'Taper',
      EventPhase.eventWeek => 'Event week',
      EventPhase.complete => 'Complete',
    };
