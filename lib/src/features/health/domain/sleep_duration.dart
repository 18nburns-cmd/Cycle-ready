class SleepInterval {
  const SleepInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// Returns the union of overlapping sleep intervals, so a generic "asleep"
/// record and its deep/light/REM stage records are never counted twice.
int uniqueSleepMinutes(Iterable<SleepInterval> values) {
  final intervals = values
      .where((value) => value.end.isAfter(value.start))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (intervals.isEmpty) return 0;

  var total = 0;
  var start = intervals.first.start;
  var end = intervals.first.end;
  for (final interval in intervals.skip(1)) {
    if (!interval.start.isAfter(end)) {
      if (interval.end.isAfter(end)) end = interval.end;
    } else {
      total += end.difference(start).inMinutes;
      start = interval.start;
      end = interval.end;
    }
  }
  return total + end.difference(start).inMinutes;
}
