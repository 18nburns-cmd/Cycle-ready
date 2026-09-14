import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;
const ALGORITHM_VERSION = 'athlete-capabilities-v2.0.0';
const dimensions = [
  'aerobic_endurance', 'tempo', 'threshold', 'vo2_max',
  'anaerobic_capacity', 'sprint_power', 'climbing', 'durability',
  'repeatability', 'recovery_between_efforts', 'heat_tolerance', 'pacing',
  'fueling',
] as const;
const requiredEnv = (name: string): string => {
  const result = Deno.env.get(name)?.trim();
  if (!result) throw new Error(`Missing server secret: ${name}`);
  return result;
};
const num = (input: unknown): number | null => {
  const parsed = Number(input);
  return input == null || !Number.isFinite(parsed) ? null : parsed;
};
const clamp = (input: number): number => Math.max(0, Math.min(100, input));
const average = (values: number[]): number | null => values.length === 0
  ? null
  : values.reduce((sum, value) => sum + value, 0) / values.length;

const evidenceScores = (activities: Json[], analyses: Json[], ftp: number) => {
  const scores: Record<string, number[]> = Object.fromEntries(dimensions.map((name) => [name, []]));
  const references: Record<string, string[]> = Object.fromEntries(dimensions.map((name) => [name, []]));
  const add = (name: typeof dimensions[number], score: number, id: unknown) => {
    scores[name].push(clamp(score));
    if (id != null) references[name].push(String(id));
  };
  for (const activity of activities) {
    const durationHours = (num(activity.duration_seconds) ?? 0) / 3600;
    const averagePower = num(activity.average_power);
    const maximumPower = num(activity.maximum_power);
    const cadence = num(activity.average_cadence);
    const elevation = num(activity.elevation_metres) ?? 0;
    const distanceKm = (num(activity.distance_metres) ?? 0) / 1000;
    if (durationHours >= 1) add('aerobic_endurance', 45 + durationHours * 15, activity.id);
    if (durationHours >= 2) add('durability', 35 + durationHours * 18, activity.id);
    if (averagePower !== null && ftp > 0) {
      const ratio = averagePower / ftp;
      if (ratio >= 0.75 && ratio < 0.9) add('tempo', ratio / 0.9 * 100, activity.id);
      if (ratio >= 0.88) add('threshold', ratio / 1.05 * 100, activity.id);
      add('pacing', 55 + Math.min(35, durationHours * 8), activity.id);
    }
    if (maximumPower !== null && ftp > 0) {
      add('sprint_power', maximumPower / (ftp * 5) * 100, activity.id);
      add('anaerobic_capacity', maximumPower / (ftp * 2.2) * 100, activity.id);
      add('vo2_max', maximumPower / (ftp * 1.3) * 75, activity.id);
    }
    if (distanceKm > 0 && elevation > 0) add('climbing', 35 + elevation / distanceKm * 3, activity.id);
    if (cadence !== null) add('repeatability', 55 + Math.min(25, Math.abs(cadence - 85) < 10 ? 20 : 5), activity.id);
    if (durationHours >= 1.5) add('fueling', 45 + durationHours * 10, activity.id);
  }
  for (const analysis of analyses) {
    const score = num(analysis.stimulus_achievement_score);
    if (score === null) continue;
    const family = String(analysis.planned_sessions?.session_type ?? '');
    const map: Record<string, typeof dimensions[number]> = {
      endurance: 'aerobic_endurance', tempo: 'tempo', sweet_spot: 'threshold',
      threshold: 'threshold', vo2_max: 'vo2_max', anaerobic: 'anaerobic_capacity',
      sprint: 'sprint_power', climbing: 'climbing', race_simulation: 'durability',
    };
    if (map[family]) add(map[family], score, analysis.activity_id);
    if (analysis.absorbed === true) add('recovery_between_efforts', 85, analysis.activity_id);
    else if (analysis.recovery_cost_score != null) add('recovery_between_efforts', 100 - (num(analysis.recovery_cost_score) ?? 50), analysis.activity_id);
  }
  return { scores, references };
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
  try {
    if (request.headers.get('x-cycle-ready-sync-secret') !== requiredEnv('CYCLEREADY_SYNC_JOB_SECRET')) return Response.json({ error: 'Unauthorized' }, { status: 401 });
    const body = await request.json().catch(() => ({})) as Json;
    const capabilityDate = typeof body.date === 'string' ? body.date : new Date().toISOString().slice(0, 10);
    const since = new Date(`${capabilityDate}T00:00:00.000Z`);
    since.setUTCDate(since.getUTCDate() - 90);
    const supabase = createClient(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    let athleteQuery = supabase.from('athletes').select('id,current_ftp');
    if (typeof body.athlete_id === 'string') athleteQuery = athleteQuery.eq('id', body.athlete_id);
    const { data: athletes, error: athleteError } = await athleteQuery;
    if (athleteError) throw athleteError;
    const output: Json[] = [];
    for (const athlete of athletes ?? []) {
      const [activitiesResult, analysesResult, previousResult] = await Promise.all([
        supabase.from('activities').select('*').eq('athlete_id', athlete.id).gte('started_at', since.toISOString()).lte('started_at', `${capabilityDate}T23:59:59.999Z`),
        supabase.from('session_analysis').select('*,planned_sessions(session_type)').eq('athlete_id', athlete.id).eq('analysis_status', 'complete').order('analysed_at', { ascending: false }).limit(30),
        supabase.from('athlete_capabilities').select('*').eq('athlete_id', athlete.id).lt('capability_date', capabilityDate).order('capability_date', { ascending: false }).limit(1).maybeSingle(),
      ]);
      if (activitiesResult.error) throw activitiesResult.error;
      if (analysesResult.error) throw analysesResult.error;
      if (previousResult.error) throw previousResult.error;
      const evidence = evidenceScores(activitiesResult.data ?? [], analysesResult.data ?? [], num(athlete.current_ftp) ?? 0);
      const prior = previousResult.data?.capability_scores as Json | undefined;
      const capabilityScores: Json = {};
      let evidenceCount = 0;
      let dimensionsWithEvidence = 0;
      for (const dimension of dimensions) {
        const observed = average(evidence.scores[dimension]);
        const previous = num(prior?.[dimension]) ?? 50;
        evidenceCount += evidence.scores[dimension].length;
        if (observed === null) {
          capabilityScores[dimension] = Math.round(previous * 100) / 100;
        } else {
          dimensionsWithEvidence++;
          capabilityScores[dimension] = Math.round(clamp(previous + Math.max(-5, Math.min(5, observed - previous))) * 100) / 100;
        }
      }
      const confidence = Math.round(Math.min(1, dimensionsWithEvidence / dimensions.length * 0.7 + Math.min(0.3, evidenceCount / 100)) * 1000) / 1000;
      const result = await supabase.from('athlete_capabilities').upsert({
        athlete_id: athlete.id, capability_date: capabilityDate,
        capability_scores: capabilityScores, confidence, evidence_count: evidenceCount,
        evidence: { dimension_source_ids: evidence.references, lookback_days: 90, missing_dimensions_are_carried_forward: true },
        last_evidence_at: evidenceCount > 0 ? new Date().toISOString() : previousResult.data?.last_evidence_at ?? null,
        algorithm_version: ALGORITHM_VERSION, calculated_at: new Date().toISOString(),
      }, { onConflict: 'athlete_id,capability_date,algorithm_version' });
      if (result.error) throw result.error;
      output.push({ athlete_id: athlete.id, capability_date: capabilityDate, capability_scores: capabilityScores, confidence, evidence_count: evidenceCount });
    }
    return Response.json({ algorithm_version: ALGORITHM_VERSION, capabilities: output });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Unknown capability error' }, { status: 500 });
  }
});
