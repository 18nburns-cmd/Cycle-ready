import { assert, assertEquals } from 'jsr:@std/assert@1';
import { evaluateAdaptiveSafety } from './adaptive-safety.ts';

type Json = Record<string, unknown>;

const fixture = JSON.parse(
  await Deno.readTextFile(
    new URL(
      '../../../test/fixtures/golden_athlete_timelines.json',
      import.meta.url,
    ),
  ),
) as { timelines: Json[] };

Deno.test('server safety replays every golden athlete day', () => {
  for (const timeline of fixture.timelines) {
    for (const day of timeline.days as Json[]) {
      const evidence = day.evidence as Json;
      const expected = day.expected as Json;
      const result = evaluateAdaptiveSafety({
        illness: evidence.illness_symptoms === true,
        injury: evidence.injury_pain === true,
        athleteState: evidence.illness_symptoms === true ||
            evidence.injury_pain === true
          ? 'RED'
          : Number(evidence.readiness) < 45
          ? 'ORANGE'
          : Number(evidence.readiness) < 60
          ? 'YELLOW'
          : 'GREEN',
        availableMinutes: Number(evidence.available_minutes),
      });
      const safetyRest = evidence.illness_symptoms === true ||
        evidence.injury_pain === true || Number(evidence.available_minutes) <= 0;
      assertEquals(
        result.outcome,
        safetyRest ? 'REST' : 'CONTINUE',
        `${timeline.id} ${day.date}`,
      );
      if (result.outcome === 'REST') {
        assert(
          (expected.allowed_actions as string[]).includes('REST'),
          `${timeline.id} ${day.date}`,
        );
      }
    }
  }
});
