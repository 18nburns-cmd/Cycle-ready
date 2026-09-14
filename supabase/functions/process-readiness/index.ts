import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;
const ALGORITHM_VERSION = 'readiness-v2.0.0';

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};
const value = (input: unknown): number | null => {
  const parsed = typeof input === 'number' ? input : Number(input);
  return input == null || !Number.isFinite(parsed) ? null : parsed;
};
const clamp = (input: number): number => Math.max(0, Math.min(100, input));
const round = (input: number): number => Math.round(input * 100) / 100;
const today = (): string => new Date().toISOString().slice(0, 10);

const scoreReadiness = (
  wellness: Json | null,
  baseline: Json | null,
  metrics: Json | null,
) => {
  const evidence: Json = {};
  const reasons: string[] = [];
  let availableWeight = 0;

  const sleepMinutes = value(wellness?.sleep_minutes);
  const sleepQuality = value(wellness?.sleep_quality);
  const hasSleep = sleepMinutes !== null || sleepQuality !== null;
  const sleepDurationScore = sleepMinutes === null ? 50 : clamp(sleepMinutes / 480 * 100);
  const qualityScore = sleepQuality === null ? 50 : clamp(sleepQuality * 10);
  const sleepScore = sleepDurationScore * 0.7 + qualityScore * 0.3;
  if (hasSleep) availableWeight += 0.3;
  if ((sleepMinutes ?? 480) < 420) reasons.push('SLEEP_DEFICIT');
  evidence.sleep = { score: round(sleepScore), available: hasSleep };

  const hrv = value(wellness?.hrv_ms);
  const rhr = value(wellness?.resting_hr);
  const hrvBaseline = value(baseline?.hrv_baseline_ms);
  const rhrBaseline = value(baseline?.resting_hr_baseline);
  const hasRecovery = hrv !== null || rhr !== null;
  const hrvScore = hrv === null || hrvBaseline === null || hrvBaseline <= 0
    ? 50
    : clamp(hrv / hrvBaseline * 100);
  const rhrDelta = rhr === null || rhrBaseline === null ? 0 : rhr - rhrBaseline;
  const rhrScore = rhr === null || rhrBaseline === null ? 50 : clamp(100 - Math.max(0, rhrDelta) * 8);
  const recoveryScore = hrv !== null && hrvBaseline !== null && rhr !== null && rhrBaseline !== null
    ? (hrvScore + rhrScore) / 2
    : hrv !== null && hrvBaseline !== null ? hrvScore : rhrScore;
  if (hasRecovery) availableWeight += 0.3;
  if (hrv !== null && hrvBaseline !== null && hrv <= hrvBaseline * 0.9) reasons.push('HRV_SUPPRESSED');
  if (rhrDelta >= 5) reasons.push('RESTING_HR_ELEVATED');
  evidence.recovery = { score: round(recoveryScore), available: hasRecovery, hrv, hrv_baseline: hrvBaseline, resting_hr: rhr, resting_hr_baseline: rhrBaseline };

  const load7 = value(metrics?.load_7_day);
  const load28 = value(metrics?.load_28_day);
  const hasLoad = load7 !== null && load28 !== null;
  const normalWeeklyLoad = load28 === null ? null : load28 / 4;
  const loadRatio = load7 === null || normalWeeklyLoad === null || normalWeeklyLoad <= 0
    ? null
    : load7 / normalWeeklyLoad;
  const loadScore = loadRatio === null ? 50 : loadRatio <= 1
    ? clamp(100 - Math.abs(1 - loadRatio) * 15)
    : clamp(100 - (loadRatio - 1) * 80);
  if (hasLoad) availableWeight += 0.2;
  if ((loadRatio ?? 0) > 1.5) reasons.push('ACUTE_LOAD_HIGH');
  evidence.training_load = { score: round(loadScore), available: hasLoad, load_7_day: load7, normal_weekly_load: normalWeeklyLoad };

  const fatigue = value(wellness?.fatigue);
  const soreness = value(wellness?.soreness);
  const stress = value(wellness?.stress);
  const motivation = value(wellness?.motivation);
  const subjectiveValues = [fatigue, soreness, stress, motivation].filter((item): item is number => item !== null);
  const hasSubjective = subjectiveValues.length > 0;
  const fatigueWellbeing = fatigue === null ? 50 : clamp(100 - fatigue * 10);
  const sorenessWellbeing = soreness === null ? 50 : clamp(100 - soreness * 10);
  const stressWellbeing = stress === null ? 50 : clamp(100 - stress * 10);
  const motivationScore = motivation === null ? 50 : clamp(motivation * 10);
  const subjectiveScore = (fatigueWellbeing + sorenessWellbeing + stressWellbeing + motivationScore) / 4;
  if (hasSubjective) availableWeight += 0.2;
  if ((fatigue ?? 0) >= 8) reasons.push('HIGH_FATIGUE');
  if ((soreness ?? 0) >= 8) reasons.push('HIGH_SORENESS');
  evidence.subjective = { score: round(subjectiveScore), available: hasSubjective };

  const illness = wellness?.illness_flag === true;
  const injury = wellness?.injury_or_pain_flag === true;
  if (illness) reasons.push('ILLNESS_FLAG');
  if (injury) reasons.push('INJURY_OR_PAIN_FLAG');
  const readiness = clamp(sleepScore * 0.3 + recoveryScore * 0.3 + loadScore * 0.2 + subjectiveScore * 0.2);
  const fatigueRisk = clamp(100 - (recoveryScore * 0.4 + loadScore * 0.3 + subjectiveScore * 0.3));
  const athleteState = illness || injury ? 'RED'
    : readiness < 45 || fatigueRisk >= 70 ? 'ORANGE'
    : readiness < 60 || fatigueRisk >= 55 ? 'YELLOW'
    : 'GREEN';
  reasons.unshift(readiness < 60 ? 'READINESS_LOW' : readiness >= 75 ? 'READINESS_HIGH' : 'READINESS_NORMAL');
  return {
    readiness_score: round(readiness),
    recovery_score: round(recoveryScore),
    fatigue_score: round(fatigueRisk),
    fatigue_risk: fatigueRisk >= 70 ? 'HIGH' : fatigueRisk >= 45 ? 'MODERATE' : 'LOW',
    athlete_state: athleteState,
    data_confidence: round(availableWeight),
    contributing_metrics: evidence,
    reason_codes: [...new Set(reasons)],
  };
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
  try {
    if (request.headers.get('x-cycle-ready-sync-secret') !== requiredEnv('CYCLEREADY_SYNC_JOB_SECRET')) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const body = await request.json().catch(() => ({})) as Json;
    const date = typeof body.date === 'string' ? body.date : today();
    const supabase = createClient(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    let athleteQuery = supabase.from('athletes').select('id');
    if (typeof body.athlete_id === 'string') athleteQuery = athleteQuery.eq('id', body.athlete_id);
    const { data: athletes, error: athleteError } = await athleteQuery;
    if (athleteError) throw athleteError;
    const results: Json[] = [];
    for (const athlete of athletes ?? []) {
      const [wellnessResult, baselineResult, metricsResult] = await Promise.all([
        supabase.from('daily_wellness_resolved').select('*').eq('athlete_id', athlete.id).eq('recorded_date', date).maybeSingle(),
        supabase.from('athlete_metric_baselines').select('*').eq('athlete_id', athlete.id).lte('baseline_date', date).order('baseline_date', { ascending: false }).limit(1).maybeSingle(),
        supabase.from('daily_training_metrics').select('*').eq('athlete_id', athlete.id).lte('metric_date', date).order('metric_date', { ascending: false }).limit(1).maybeSingle(),
      ]);
      if (wellnessResult.error) throw wellnessResult.error;
      if (baselineResult.error) throw baselineResult.error;
      if (metricsResult.error) throw metricsResult.error;
      const score = scoreReadiness(wellnessResult.data, baselineResult.data, metricsResult.data);
      const sourceReferences = {
        wellness_observation_id: wellnessResult.data?.source_observation_id ?? null,
        baseline_date: baselineResult.data?.baseline_date ?? null,
        training_metric_date: metricsResult.data?.metric_date ?? null,
      };
      const readiness = await supabase.from('daily_readiness').upsert({
        athlete_id: athlete.id,
        readiness_date: date,
        ...score,
        source_references: sourceReferences,
        algorithm_version: ALGORITHM_VERSION,
        calculated_at: new Date().toISOString(),
      }, { onConflict: 'athlete_id,readiness_date,algorithm_version' }).select('id').single();
      if (readiness.error) throw readiness.error;
      const snapshot = await supabase.from('coaching_state_snapshots').upsert({
        athlete_id: athlete.id,
        effective_at: new Date().toISOString(),
        athlete_state: score.athlete_state,
        readiness_id: readiness.data.id,
        state_payload: score,
        evidence: sourceReferences,
        confidence: score.data_confidence,
        algorithm_version: ALGORITHM_VERSION,
      }, { onConflict: 'readiness_id,algorithm_version' });
      if (snapshot.error) throw snapshot.error;
      results.push({ athlete_id: athlete.id, date, ...score });
    }
    return Response.json({ algorithm_version: ALGORITHM_VERSION, results });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Unknown processing error' }, { status: 500 });
  }
});
