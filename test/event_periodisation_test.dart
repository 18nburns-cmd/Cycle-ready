import 'package:cycle_ready/src/features/coaching/domain/event_periodisation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moves through base, build, specific, taper and event week', () {
    final event = DateTime(2026, 10, 24);
    expect(eventPhaseFor(DateTime(2026, 7, 1), event), EventPhase.base);
    expect(eventPhaseFor(DateTime(2026, 8, 15), event), EventPhase.build);
    expect(eventPhaseFor(DateTime(2026, 10, 1), event), EventPhase.specific);
    expect(eventPhaseFor(DateTime(2026, 10, 16), event), EventPhase.taper);
    expect(eventPhaseFor(DateTime(2026, 10, 22), event), EventPhase.eventWeek);
  });

  test('periodisation blocks cover every day through the event', () {
    final now = DateTime(2026, 7, 1);
    final event = DateTime(2026, 10, 24);
    final blocks = buildEventBlocks(now: now, eventDate: event);
    expect(blocks.first.start, now);
    expect(blocks.last.end, event);
    expect(blocks.map((item) => item.phase), contains(EventPhase.taper));
    for (var index = 1; index < blocks.length; index++) {
      expect(
        blocks[index].start,
        blocks[index - 1].end.add(const Duration(days: 1)),
      );
    }
  });
}
