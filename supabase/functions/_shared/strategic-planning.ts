export type Json = Record<string, unknown>;
export type TrainingPhase = 'FOUNDATION' | 'BASE' | 'BUILD' | 'SPECIALTY' | 'TAPER' | 'RECOVERY_TRANSITION';
export const dimensions = [
  'aerobic_endurance', 'durability', 'tempo', 'threshold', 'vo2_max',
  'anaerobic_capacity', 'sprint_power', 'climbing_endurance',
  'muscular_endurance', 'fatigue_resistance', 'repeatability',
] as const;
export type CapabilityDimension = typeof dimensions[number];

export type EventInput = {
  event_type: string;
  distance_metres: number | string | null;
  elevation_metres: number | string | null;
  expected_duration_seconds: number | null;
  terrain?: string | null;
};

export type CapabilityGap = {
  dimension: CapabilityDimension;
  demand: number;
  capability: number;
  raw_gap: number;
  priority: number;
  confidence: number;
};

const num = (value: unknown): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};
const score = (value: number): number => Math.max(0, Math.min(100, Math.round(value * 100) / 100));

export const calculateEventDemands = (event: EventInput): Record<CapabilityDimension, number> => {
  const distanceKm = num(event.distance_metres) / 1000;
  const durationHours = event.expected_duration_seconds
    ? event.expected_duration_seconds / 3600
    : Math.max(1, distanceKm / 25);
  const duration = Math.min(1, durationHours / 8);
  const distance = Math.min(1, distanceKm / 200);
  const climbing = Math.min(1, num(event.elevation_metres) / 3500);
  const type = event.event_type.toLowerCase();
  const terrainText = (event.terrain ?? '').toLowerCase();
  const terrain = /mountain/.test(terrainText) ? 1
    : /hill/.test(terrainText) ? .75
    : /roll/.test(terrainText) ? .4
    : Math.min(1, climbing * 1.15);
  const competition = /road.?race|criterium/.test(type) ? 1
    : /time.?trial|\btt\b/.test(type) ? .75
    : /gran/.test(type) ? .55
    : /sportive/.test(type) ? .35
    : /audax/.test(type) ? .15 : .3;
  const steady = /time.?trial|\btt\b/.test(type) ? 1 : .55;
  const ultra = /audax/.test(type) ? 1 : duration;
  return {
    aerobic_endurance: score(50 + 30 * duration + 20 * distance),
    durability: score(35 + 35 * duration + 30 * ultra),
    tempo: score(35 + 30 * duration + 20 * steady),
    threshold: score(30 + 25 * competition + 20 * climbing + 15 * steady),
    vo2_max: score(20 + 35 * competition + 20 * terrain),
    anaerobic_capacity: score(10 + 45 * competition),
    sprint_power: score(5 + 55 * competition),
    climbing_endurance: score(10 + 55 * climbing + 30 * terrain),
    muscular_endurance: score(25 + 30 * duration + 30 * terrain),
    fatigue_resistance: score(25 + 40 * duration + 30 * ultra),
    repeatability: score(20 + 45 * competition + 20 * terrain),
  };
};

export const analyseCapabilityGaps = (
  demands: Record<CapabilityDimension, number>,
  capabilities: Json | null,
  dimensionConfidence: Json | null,
): CapabilityGap[] => dimensions.map((dimension) => {
  const demand = demands[dimension];
  const capability = capabilities?.[dimension] == null ? 50 : num(capabilities[dimension]);
  const confidence = dimensionConfidence?.[dimension] == null
    ? capabilities?.[dimension] == null ? 0 : .5
    : Math.max(0, Math.min(1, num(dimensionConfidence[dimension])));
  const rawGap = Math.max(0, demand - capability);
  return {
    dimension,
    demand,
    capability,
    raw_gap: rawGap,
    priority: rawGap * demand / 100 * (.5 + confidence * .5),
    confidence,
  };
}).sort((left, right) => right.priority - left.priority || left.dimension.localeCompare(right.dimension));

export const phaseFor = ({
  daysRemaining,
  consistency,
  largestGap,
  recoveryTransition = false,
}: {
  daysRemaining: number;
  consistency: number;
  largestGap: number;
  recoveryTransition?: boolean;
}): TrainingPhase => {
  if (recoveryTransition || daysRemaining < 0) return 'RECOVERY_TRANSITION';
  if (daysRemaining <= 14) return 'TAPER';
  const specialtyHorizon = largestGap < 12 ? 70 : 56;
  if (daysRemaining <= specialtyHorizon) return 'SPECIALTY';
  const buildHorizon = largestGap >= 25 ? 140 : 112;
  if (daysRemaining <= buildHorizon) return 'BUILD';
  if (daysRemaining <= 224 && consistency >= .6) return 'BASE';
  return 'FOUNDATION';
};

export const phasePurpose = (phase: TrainingPhase): string => ({
  FOUNDATION: 'Build aerobic consistency, efficiency and durable training habits',
  BASE: 'Develop broad event-relevant endurance and supporting capabilities',
  BUILD: 'Develop the most important event-relevant capability gaps',
  SPECIALTY: 'Rehearse event-specific demands, pacing, durability and fuelling',
  TAPER: 'Reduce fatigue while preserving event-relevant fitness',
  RECOVERY_TRANSITION: 'Recover, absorb the prior block and reassess capabilities',
}[phase]);

export const phaseDefaults = (phase: TrainingPhase): [CapabilityDimension, CapabilityDimension] => ({
  FOUNDATION: ['aerobic_endurance', 'durability'],
  BASE: ['aerobic_endurance', 'durability'],
  BUILD: ['threshold', 'durability'],
  SPECIALTY: ['fatigue_resistance', 'repeatability'],
  TAPER: ['aerobic_endurance', 'threshold'],
  RECOVERY_TRANSITION: ['aerobic_endurance', 'durability'],
}[phase] as [CapabilityDimension, CapabilityDimension]);

const familyDimension = (family: string): CapabilityDimension => ({
  recovery: 'aerobic_endurance', endurance: 'aerobic_endurance', cadence: 'aerobic_endurance',
  long_endurance: 'durability', tempo: 'tempo', sweet_spot: 'tempo',
  threshold: 'threshold', over_under: 'threshold', vo2_max: 'vo2_max',
  anaerobic: 'anaerobic_capacity', sprint: 'sprint_power',
  neuromuscular: 'sprint_power', climbing: 'climbing_endurance',
  strength_endurance: 'muscular_endurance', race_simulation: 'fatigue_resistance',
  fatigue_resistance: 'fatigue_resistance',
}[family] ?? 'aerobic_endurance') as CapabilityDimension;

export const workoutFamilyEligibility = ({
  family, phase, primary, secondary, maintenance, demands,
}: {
  family: string;
  phase: string;
  primary: string;
  secondary?: string | null;
  maintenance: string[];
  demands: Json;
}): { weight: number; reason_codes: string[]; eligible: boolean } => {
  const normalizedPhase: TrainingPhase = phase === 'PEAK' ? 'SPECIALTY'
    : phase === 'RECOVERY' || phase === 'TRANSITION' ? 'RECOVERY_TRANSITION'
    : phase as TrainingPhase;
  const foundation: Record<string, number> = {
    recovery: 1, endurance: 1, long_endurance: 1, tempo: .7, sprint: .5,
    neuromuscular: .5, cadence: .45, strength_endurance: .45, climbing: .4,
    sweet_spot: .3, threshold: .2, vo2_max: .15, fatigue_resistance: .1,
    over_under: .05, anaerobic: .05, race_simulation: 0,
  };
  const phaseBase = normalizedPhase === 'FOUNDATION' ? foundation[family] ?? 0
    : normalizedPhase === 'TAPER' && ['anaerobic', 'fatigue_resistance'].includes(family) ? 0
    : normalizedPhase === 'RECOVERY_TRANSITION'
    ? ['recovery', 'endurance', 'cadence'].includes(family) ? .5 : 0
    : normalizedPhase === 'BASE' && ['anaerobic', 'race_simulation'].includes(family) ? .15
    : normalizedPhase === 'SPECIALTY' && ['race_simulation', 'long_endurance', 'fatigue_resistance'].includes(family) ? 1
    : normalizedPhase === 'BUILD' ? .75 : .55;
  const dimension = familyDimension(family);
  let weight = phaseBase;
  const reasons = [`PHASE_${normalizedPhase}`];
  if (dimension === primary) { weight *= 1.5; reasons.push('PRIMARY_ADAPTATION'); }
  else if (dimension === secondary) { weight *= 1.25; reasons.push('SECONDARY_ADAPTATION'); }
  else if (maintenance.includes(dimension)) reasons.push('MAINTENANCE_ADAPTATION');
  const demand = num(demands[dimension]);
  weight *= .5 + demand / 200;
  if (demand >= 75) reasons.push('EVENT_DEMAND_HIGH');
  return { weight: Math.max(0, Math.min(1, weight)), reason_codes: reasons, eligible: weight > 0 };
};

export const adaptationChangeTier = ({
  candidate, current, intendedAdaptation,
}: {
  candidate: Json;
  current: Json | null;
  intendedAdaptation: string;
}): number => {
  if (candidate.id === current?.id) return 0;
  const sameFamily = candidate.session_type === current?.session_type;
  if (sameFamily && num(candidate.duration_minutes) < num(current?.duration_minutes)) return 1;
  if (sameFamily && num(candidate.difficulty_level) <= num(current?.difficulty_level)) return 2;
  if (String(candidate.primary_adaptation) === intendedAdaptation) return 3;
  if (['tempo', 'sweet_spot'].includes(String(candidate.session_type))) return 4;
  if (candidate.session_type === 'endurance') return 5;
  if (candidate.session_type === 'recovery') return 6;
  return 7;
};
