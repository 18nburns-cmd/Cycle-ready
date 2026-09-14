import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;
const ALGORITHM_VERSION = 'session-analysis-v2.0.0';
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
const round = (input: number): number => Math.round(input * 100) / 100;
const day = (timestamp: string): string => timestamp.slice(0, 10);

const familyWeights = (family: string) => {
  const normalized = family.toLowerCase();
  if (/recovery/.test(normalized)) return { completion: 0.2, target: 0.15, physiology: 0.35, subjective: 0.3 };
  if (/endurance|zone.?2|long/.test(normalized)) return { completion: 0.25, target: 0.2, physiology: 0.35, subjective: 0.2 };
  if (/sprint|anaerobic|vo2/.test(normalized)) return { completion: 0.3, target: 0.4, physiology: 0.15, subjective: 0.15 };
  return { completion: 0.3, target: 0.3, physiology: 0.2, subjective: 0.2 };
};

const validPwHr = (intervals: Json[]): number | null => {
  const steady = intervals.filter((item) =>
    (num(item.duration_seconds) ?? 0) >= 300 &&
    (num(item.average_power) ?? 0) > 0 &&
    (num(item.average_hr) ?? 0) > 0 &&
    !/recovery|warm|cool|sprint/i.test(String(item.interval_type ?? ''))
  );
  if (steady.length < 2) return null;
  const half = Math.floor(steady.length / 2);
  const ratio = (rows: Json[]) => rows.reduce((sum, item) =>
    sum + (num(item.average_power) ?? 0) / (num(item.average_hr) ?? 1), 0) / rows.length;
  const early = ratio(steady.slice(0, half));
  const late = ratio(steady.slice(-half));
  if (early <= 0 || late <= 0) return null;
  return round((early - late) / early * 100);
};

const durability = (activity: Json, intervals: Json[]): number | null => {
  if ((num(activity.duration_seconds) ?? 0) < 5400) return null;
  const powered = intervals.filter((item) => (num(item.average_power) ?? 0) > 0);
  if (powered.length < 4) return null;
  const quarter = Math.max(1, Math.floor(powered.length / 4));
  const average = (rows: Json[]) => rows.reduce((sum, item) => sum + (num(item.average_power) ?? 0), 0) / rows.length;
  const first = average(powered.slice(0, quarter));
  const last = average(powered.slice(-quarter));
  return first <= 0 ? null : round(clamp(last / first * 100));
};

const immediateScore = (activity: Json, planned: Json | null, intervals: Json[]) => {
  const actualMinutes = (num(activity.duration_seconds) ?? 0) / 60;
  const plannedMinutes = num(planned?.planned_duration_minutes);
  const completion = plannedMinutes && plannedMinutes > 0 ? clamp(actualMinutes / plannedMinutes * 100) : 70;
  const targetIntervals = intervals.filter((item) => (num(item.target_power) ?? 0) > 0 && (num(item.average_power) ?? 0) > 0);
  const target = targetIntervals.length === 0 ? 60 : targetIntervals.reduce((sum, item) => {
    const ratio = (num(item.average_power) ?? 0) / (num(item.target_power) ?? 1);
    return sum + clamp(100 - Math.abs(1 - ratio) * 200);
  }, 0) / targetIntervals.length;
  const decoupling = validPwHr(intervals);
  const physiology = decoupling === null ? 60 : clamp(100 - Math.max(0, decoupling - 3) * 8);
  const rpe = num(activity.rpe);
  const subjective = rpe === null ? 50 : clamp(100 - Math.max(0, rpe - 7) * 15);
  const family = String(planned?.session_type ?? 'unplanned');
  const weights = familyWeights(family);
  const sas = completion * weights.completion + target * weights.target + physiology * weights.physiology + subjective * weights.subjective;
  const failureReasons: string[] = [];
  if (completion < 70) failureReasons.push('INCOMPLETE_DURATION');
  if (target < 70 && targetIntervals.length > 0) failureReasons.push('TARGET_EXECUTION_LOW');
  if (decoupling !== null && decoupling > 7.5) failureReasons.push('CARDIOVASCULAR_DRIFT_HIGH');
  if (rpe !== null && rpe >= 9) failureReasons.push('SUBJECTIVE_COST_HIGH');
  return {
    sas: round(sas), completion: round(completion), target: round(target),
    physiology: round(physiology), subjective: round(subjective),
    decoupling, durability: durability(activity, intervals), failureReasons,
    confidence: round(Math.min(1, 0.35 + (planned ? 0.2 : 0) + (intervals.length > 0 ? 0.25 : 0) + (rpe !== null ? 0.2 : 0))),
  };
};

const recoveryCost = (analysis: Json, wellness: Json | null, baseline: Json | null): number | null => {
  if (!wellness) return null;
  const hrv = num(wellness.hrv_ms);
  const baselineHrv = num(baseline?.hrv_baseline_ms);
  const rhr = num(wellness.resting_hr);
  const baselineRhr = num(baseline?.resting_hr_baseline);
  const fatigue = num(wellness.fatigue);
  const soreness = num(wellness.soreness);
  const stress = num(wellness.stress);
  const components: number[] = [];
  if (hrv !== null && baselineHrv !== null && baselineHrv > 0) components.push(clamp((1 - hrv / baselineHrv) * 200 + 30));
  if (rhr !== null && baselineRhr !== null) components.push(clamp((rhr - baselineRhr) * 10 + 25));
  if (fatigue !== null) components.push(clamp(fatigue * 10));
  if (soreness !== null) components.push(clamp(soreness * 10));
  if (stress !== null) components.push(clamp(stress * 10));
  if (components.length === 0) return null;
  const observed = components.reduce((sum, component) => sum + component, 0) / components.length;
  const sas = num(analysis.stimulus_achievement_score) ?? 50;
  return round(clamp(observed * 0.8 + Math.max(0, sas - 80) * 0.2));
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
  try {
    if (request.headers.get('x-cycle-ready-sync-secret') !== requiredEnv('CYCLEREADY_SYNC_JOB_SECRET')) return Response.json({ error: 'Unauthorized' }, { status: 401 });
    const body = await request.json().catch(() => ({})) as Json;
    const mode = body.mode === 'recovery' ? 'recovery' : 'immediate';
    const supabase = createClient(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    if (mode === 'immediate') {
      let activityQuery = supabase.from('activities').select('*').order('started_at');
      if (typeof body.activity_id === 'string') activityQuery = activityQuery.eq('id', body.activity_id);
      if (typeof body.athlete_id === 'string') activityQuery = activityQuery.eq('athlete_id', body.athlete_id);
      if (typeof body.oldest === 'string') activityQuery = activityQuery.gte('started_at', `${body.oldest}T00:00:00.000Z`);
      const { data: activities, error } = await activityQuery;
      if (error) throw error;
      const output: Json[] = [];
      for (const activity of activities ?? []) {
        const activityDay = day(activity.started_at);
        const [plannedResult, intervalResult] = await Promise.all([
          supabase.from('planned_sessions').select('*').eq('athlete_id', activity.athlete_id).eq('scheduled_date', activityDay).order('created_at').limit(1).maybeSingle(),
          supabase.from('activity_intervals').select('*').eq('activity_id', activity.id).order('interval_number'),
        ]);
        if (plannedResult.error) throw plannedResult.error;
        if (intervalResult.error) throw intervalResult.error;
        const score = immediateScore(activity, plannedResult.data, intervalResult.data ?? []);
        const outcome = score.sas >= 80 ? 'ACHIEVED' : score.sas >= 60 ? 'PARTIALLY_ACHIEVED' : 'NOT_ACHIEVED';
        const result = await supabase.from('session_analysis').upsert({
          athlete_id: activity.athlete_id, activity_id: activity.id,
          planned_session_id: plannedResult.data?.id ?? null, session_outcome: outcome,
          stimulus_achievement_score: score.sas, recovery_cost_score: null,
          durability_score: score.durability, pw_hr_decoupling: score.decoupling,
          interval_completion: score.completion, target_power_achievement: score.target,
          rpe: activity.rpe, adaptation_achieved: score.sas >= 80, absorbed: null,
          interpretation: score.sas >= 80 ? 'The intended session stimulus was achieved; recovery response is pending.' : 'The intended stimulus was only partly achieved; review the failure evidence before progressing.',
          confidence: score.confidence, analysis_version: ALGORITHM_VERSION,
          analysis_status: 'provisional', failure_reasons: score.failureReasons,
          next_session_action: 'HOLD', component_scores: score,
          source_references: { activity_id: activity.id, planned_session_id: plannedResult.data?.id ?? null, interval_ids: (intervalResult.data ?? []).map((item) => item.id) },
          analysed_at: new Date().toISOString(),
        }, { onConflict: 'activity_id,analysis_version' }).select('id').single();
        if (result.error) throw result.error;
        output.push({ activity_id: activity.id, analysis_id: result.data.id, outcome, ...score });
      }
      return Response.json({ algorithm_version: ALGORITHM_VERSION, mode, analyses: output });
    }

    const minAge = new Date(Date.now() - 12 * 3_600_000).toISOString();
    const maxAge = new Date(Date.now() - 48 * 3_600_000).toISOString();
    let analysisQuery = supabase.from('session_analysis').select('*,activities!inner(started_at)').eq('analysis_status', 'provisional').lte('analysed_at', minAge).gte('analysed_at', maxAge);
    if (typeof body.analysis_id === 'string') analysisQuery = supabase.from('session_analysis').select('*,activities!inner(started_at)').eq('id', body.analysis_id);
    const { data: analyses, error: analysisError } = await analysisQuery;
    if (analysisError) throw analysisError;
    const completed: Json[] = [];
    for (const analysis of analyses ?? []) {
      const rideDate = day(analysis.activities.started_at);
      const followUpDate = new Date(`${rideDate}T00:00:00.000Z`);
      followUpDate.setUTCDate(followUpDate.getUTCDate() + 1);
      const [wellnessResult, baselineResult] = await Promise.all([
        supabase.from('daily_wellness_resolved').select('*').eq('athlete_id', analysis.athlete_id).eq('recorded_date', followUpDate.toISOString().slice(0, 10)).maybeSingle(),
        supabase.from('athlete_metric_baselines').select('*').eq('athlete_id', analysis.athlete_id).lte('baseline_date', rideDate).order('baseline_date', { ascending: false }).limit(1).maybeSingle(),
      ]);
      if (wellnessResult.error) throw wellnessResult.error;
      if (baselineResult.error) throw baselineResult.error;
      const rcs = recoveryCost(analysis, wellnessResult.data, baselineResult.data);
      if (rcs === null) continue;
      const achieved = (num(analysis.stimulus_achievement_score) ?? 0) >= 80;
      const absorbed = achieved && rcs <= 60;
      const outcome = achieved && rcs >= 70 ? 'ACHIEVED_HIGH_COST' : achieved ? 'ACHIEVED' : analysis.session_outcome;
      const nextAction = absorbed ? 'HOLD' : rcs >= 70 ? 'REDUCE' : 'HOLD';
      const update = await supabase.from('session_analysis').update({
        recovery_cost_score: rcs, absorbed, session_outcome: outcome,
        analysis_status: 'complete', next_session_action: nextAction,
        recovery_updated_at: new Date().toISOString(),
        source_references: { ...analysis.source_references, recovery_wellness_observation_id: wellnessResult.data?.source_observation_id, recovery_baseline_date: baselineResult.data?.baseline_date },
        interpretation: achieved && rcs >= 70 ? 'The target stimulus was achieved, but the recovery cost was excessive; reduce the next comparable dose.' : achieved ? 'The target stimulus was achieved and absorbed with an acceptable recovery cost.' : 'The target stimulus was not fully achieved; hold or reduce before retrying comparable work.',
      }).eq('id', analysis.id);
      if (update.error) throw update.error;
      completed.push({ analysis_id: analysis.id, recovery_cost_score: rcs, absorbed, outcome, next_session_action: nextAction });
    }
    return Response.json({ algorithm_version: ALGORITHM_VERSION, mode, analyses: completed });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Unknown analysis error' }, { status: 500 });
  }
});
