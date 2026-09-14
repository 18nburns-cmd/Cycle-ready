import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  analyseCapabilityGaps,
  adaptationChangeTier,
  calculateEventDemands,
  phaseFor,
  workoutFamilyEligibility,
} from './strategic-planning.ts';

Deno.test('long hilly sportive demands endurance durability and climbing', () => {
  const demand = calculateEventDemands({
    event_type: 'sportive',
    distance_metres: 160000,
    elevation_metres: 2800,
    expected_duration_seconds: 7 * 3600,
    terrain: 'hilly',
  });
  assert(demand.aerobic_endurance > 85);
  assert(demand.durability > 85);
  assert(demand.climbing_endurance > 70);
});

Deno.test('adaptation hierarchy prefers a smaller same-family dose', () => {
  const current = { id: 'TEMPO_003', session_type: 'tempo',
    primary_adaptation: 'tempo', duration_minutes: 70, difficulty_level: 6 };
  assertEquals(adaptationChangeTier({ candidate: { ...current, id: 'TEMPO_002',
    duration_minutes: 55 }, current, intendedAdaptation: 'tempo' }), 1);
  assertEquals(adaptationChangeTier({ candidate: { id: 'ENDURANCE_60',
    session_type: 'endurance', primary_adaptation: 'aerobic_endurance' },
    current, intendedAdaptation: 'tempo' }), 4);
});

Deno.test('Foundation excludes race simulation and prioritizes endurance', () => {
  const context = { phase: 'FOUNDATION', primary: 'aerobic_endurance',
    secondary: 'durability', maintenance: ['threshold'],
    demands: { aerobic_endurance: 95, durability: 95, threshold: 75 } };
  const endurance = workoutFamilyEligibility({ family: 'endurance', ...context });
  const threshold = workoutFamilyEligibility({ family: 'threshold', ...context });
  const race = workoutFamilyEligibility({ family: 'race_simulation', ...context });
  assert(endurance.weight > threshold.weight);
  assertEquals(race.eligible, false);
});

Deno.test('phase responds to proximity gaps and consistency', () => {
  assertEquals(phaseFor({ daysRemaining: 330, consistency: .8, largestGap: 30 }), 'FOUNDATION');
  assertEquals(phaseFor({ daysRemaining: 84, consistency: .8, largestGap: 30 }), 'BUILD');
  assertEquals(phaseFor({ daysRemaining: 10, consistency: .8, largestGap: 30 }), 'TAPER');
  assertEquals(phaseFor({ daysRemaining: 180, consistency: .3, largestGap: 10 }), 'FOUNDATION');
});

Deno.test('confidence-weighted gap prioritizes poor durability', () => {
  const demands = calculateEventDemands({
    event_type: 'sportive', distance_metres: 160000,
    elevation_metres: 1800, expected_duration_seconds: 7 * 3600,
  });
  const gaps = analyseCapabilityGaps(
    demands,
    { durability: 35, threshold: 92, aerobic_endurance: 75 },
    { durability: .9, threshold: .9, aerobic_endurance: .9 },
  );
  assertEquals(gaps[0].dimension, 'durability');
});
