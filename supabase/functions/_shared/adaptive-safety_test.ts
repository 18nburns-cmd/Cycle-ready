import { assertEquals } from 'jsr:@std/assert@1';
import { evaluateAdaptiveSafety } from './adaptive-safety.ts';

const scenarios = JSON.parse(
  await Deno.readTextFile(
    new URL('../../../test/fixtures/adaptive_safety_scenarios.json', import.meta.url),
  ),
) as Array<Record<string, unknown>>;

Deno.test('server safety matches shared golden scenarios', () => {
  for (const scenario of scenarios) {
    const result = evaluateAdaptiveSafety({
      illness: scenario.illness === true,
      injury: scenario.injury === true,
      athleteState: String(scenario.athlete_state),
      availableMinutes: Number(scenario.available_minutes),
    });
    assertEquals(result.outcome, scenario.expected, String(scenario.name));
  }
});
