import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  analyseCapabilityGaps, calculateEventDemands, CapabilityDimension, Json,
  phaseDefaults, phaseFor, phasePurpose, TrainingPhase,
} from '../_shared/strategic-planning.ts';

type Goal = { id: string; athlete_id: string; event_date: string; event_type: string;
  distance_metres: number | string | null; elevation_metres: number | string | null;
  expected_duration_seconds: number | null; notes?: string | null };
type Segment = { phase: TrainingPhase; start: Date; end: Date;
  primary: CapabilityDimension; secondary: CapabilityDimension;
  maintenance: CapabilityDimension[] };
const ALGORITHM_VERSION = 'goal-periodisation-v3.0.0';
const dayMs = 86_400_000;
const env = (name: string): string => { const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`); return value };
const date = (value: string): Date => new Date(`${value}T00:00:00.000Z`);
const key = (value: Date): string => value.toISOString().slice(0, 10);
const addDays = (value: Date, days: number): Date => new Date(value.getTime() + days * dayMs);
const daysBetween = (left: Date, right: Date): number => Math.floor((right.getTime() - left.getTime()) / dayMs);

const adaptationsFor = (phase: TrainingPhase, gaps: ReturnType<typeof analyseCapabilityGaps>) => {
  const allowed = phase === 'FOUNDATION'
    ? new Set<CapabilityDimension>(['aerobic_endurance', 'durability', 'tempo', 'muscular_endurance', 'climbing_endurance'])
    : phase === 'BASE'
    ? new Set<CapabilityDimension>(['aerobic_endurance', 'durability', 'tempo', 'threshold', 'muscular_endurance', 'climbing_endurance']) : null;
  const relevant = gaps.filter((gap) => gap.demand >= 35 && (!allowed || allowed.has(gap.dimension)));
  const defaults = phaseDefaults(phase);
  const primary = relevant[0]?.dimension ?? defaults[0];
  const secondary = relevant.find((gap) => gap.dimension !== primary)?.dimension ?? defaults[1];
  const maintenance = gaps.filter((gap) => gap.demand >= 50 &&
    gap.dimension !== primary && gap.dimension !== secondary).slice(0, 4).map((gap) => gap.dimension);
  return { primary, secondary, maintenance };
};

const buildPhases = (start: Date, event: Date, consistency: number,
  gaps: ReturnType<typeof analyseCapabilityGaps>): Segment[] => {
  const output: Segment[] = [];
  const largestGap = gaps[0]?.raw_gap ?? 0;
  let cursor = start;
  while (cursor <= event) {
    const phase = phaseFor({ daysRemaining: daysBetween(cursor, event), consistency, largestGap });
    let end = cursor;
    while (end < event) {
      const candidate = addDays(end, 1);
      if (phaseFor({ daysRemaining: daysBetween(candidate, event), consistency, largestGap }) !== phase) break;
      end = candidate;
    }
    output.push({ phase, start: cursor, end, ...adaptationsFor(phase, gaps) });
    cursor = addDays(end, 1);
  }
  return output;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
  try {
    if (request.headers.get('x-cycle-ready-sync-secret') !== env('CYCLEREADY_SYNC_JOB_SECRET'))
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    const body = await request.json().catch(() => ({})) as Json;
    const planningDate = typeof body.planning_date === 'string' ? body.planning_date : key(new Date());
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    let query = db.from('goals').select('*').gte('event_date', planningDate).order('priority').order('event_date');
    if (typeof body.goal_id === 'string') query = query.eq('id', body.goal_id);
    if (typeof body.athlete_id === 'string') query = query.eq('athlete_id', body.athlete_id);
    const { data: goals, error: goalError } = await query;
    if (goalError) throw goalError;
    const output: Json[] = [];
    for (const goal of (goals ?? []) as Goal[]) {
      const [capabilities, activities] = await Promise.all([
        db.from('athlete_capabilities').select('capability_scores,dimension_confidence,confidence,capability_date,algorithm_version')
          .eq('athlete_id', goal.athlete_id).lte('capability_date', planningDate)
          .order('capability_date', { ascending: false }).limit(1).maybeSingle(),
        db.from('activities').select('started_at').eq('athlete_id', goal.athlete_id)
          .gte('started_at', `${key(addDays(date(planningDate), -42))}T00:00:00.000Z`)
          .lte('started_at', `${planningDate}T23:59:59.999Z`),
      ]);
      if (capabilities.error) throw capabilities.error;
      if (activities.error) throw activities.error;
      const demands = calculateEventDemands({ ...goal, terrain: goal.notes });
      const gaps = analyseCapabilityGaps(demands,
        capabilities.data?.capability_scores as Json | null,
        capabilities.data?.dimension_confidence as Json | null);
      const consistency = Math.min(1, (activities.data?.length ?? 0) / 18);
      const priorities = gaps.slice(0, 4).map((gap) => gap.dimension);
      const demandWrite = await db.from('event_demand_profiles').upsert({
        athlete_id: goal.athlete_id, goal_id: goal.id, demand_scores: demands,
        demand_confidence: Object.fromEntries(Object.keys(demands).map((dimension) =>
          [dimension, goal.expected_duration_seconds ? .85 : .65])),
        model_inputs: { event_type: goal.event_type, distance_metres: goal.distance_metres,
          elevation_metres: goal.elevation_metres, expected_duration_seconds: goal.expected_duration_seconds,
          terrain_source: goal.notes ?? null },
        limiting_factors: priorities,
        evidence: { capability_date: capabilities.data?.capability_date ?? null,
          capability_algorithm: capabilities.data?.algorithm_version ?? null,
          capability_gaps: gaps, recent_activity_count_42_days: activities.data?.length ?? 0 },
        confidence: Math.min(goal.distance_metres && goal.elevation_metres ? .9 : .65,
          capabilities.data?.confidence ?? .5), algorithm_version: ALGORITHM_VERSION,
        calculated_at: new Date().toISOString(),
      }, { onConflict: 'goal_id,algorithm_version' });
      if (demandWrite.error) throw demandWrite.error;

      const phases = buildPhases(date(planningDate), date(goal.event_date), consistency, gaps);
      for (const phase of phases) {
        const purpose = phasePurpose(phase.phase);
        const reasonCodes = [`PHASE_${phase.phase}`, `BLOCK_${phase.primary.toUpperCase()}`,
          `CAPABILITY_GAP_${phase.primary.toUpperCase()}`];
        const selectionEvidence = { capability_gaps: gaps.slice(0, 6), consistency,
          event_demand_algorithm: ALGORITHM_VERSION, reason_codes: reasonCodes };
        const phaseWrite = await db.from('training_phases').upsert({
          athlete_id: goal.athlete_id, goal_id: goal.id, phase: phase.phase,
          start_date: key(phase.start), end_date: key(phase.end), purpose,
          primary_adaptation: phase.primary, secondary_adaptation: phase.secondary,
          selection_evidence: selectionEvidence, status: 'planned', algorithm_version: ALGORITHM_VERSION,
        }, { onConflict: 'athlete_id,goal_id,start_date,end_date,phase,algorithm_version' }).select('id').single();
        if (phaseWrite.error) throw phaseWrite.error;
        const duration = daysBetween(phase.start, phase.end) + 1;
        const blockWrite = await db.from('training_blocks').upsert({
          athlete_id: goal.athlete_id, goal_id: goal.id, training_phase_id: phaseWrite.data.id,
          start_date: key(phase.start), end_date: key(phase.end), phase: phase.phase, purpose,
          primary_adaptation: phase.primary, secondary_adaptation: phase.secondary,
          maintenance_adaptations: phase.maintenance, minimum_duration_days: Math.min(7, duration),
          maximum_duration_days: duration, progression_status: 'CONTINUE',
          completion_criteria: { minimum_achieved_and_absorbed_sessions: 2,
            maximum_high_cost_sessions: 1, capability_trend: 'stable_or_improving' },
          selection_evidence: selectionEvidence, status: 'planned', algorithm_version: ALGORITHM_VERSION,
        }, { onConflict: 'athlete_id,goal_id,start_date,end_date,phase,algorithm_version' }).select('id').single();
        if (blockWrite.error) throw blockWrite.error;
        for (let weekStart = phase.start; weekStart <= phase.end; weekStart = addDays(weekStart, 7)) {
          const weekly = await db.from('weekly_plans').upsert({
            athlete_id: goal.athlete_id, training_block_id: blockWrite.data.id,
            week_start: key(weekStart), purpose, primary_adaptation: phase.primary,
            secondary_adaptation: phase.secondary, maintenance_adaptations: phase.maintenance,
            adaptation_objectives: [phase.primary, phase.secondary, ...phase.maintenance],
            recovery_week: false, source_evidence: selectionEvidence, algorithm_version: ALGORITHM_VERSION,
          }, { onConflict: 'athlete_id,week_start' });
          if (weekly.error) throw weekly.error;
        }
      }
      console.log(JSON.stringify({ stage: 'strategic_plan', goal_id: goal.id,
        demands, gaps: gaps.slice(0, 6), phases }));
      output.push({ goal_id: goal.id, demand_profile: demands, capability_gaps: gaps,
        phase_count: phases.length });
    }
    return Response.json({ algorithm_version: ALGORITHM_VERSION, goals: output });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Unknown planning error' }, { status: 500 });
  }
});
