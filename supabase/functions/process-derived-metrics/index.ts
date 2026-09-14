import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;
type Activity = { id: string; started_at: string; training_load: number | string | null };
type Wellness = {
  source_observation_id: string;
  recorded_date: string;
  hrv_ms: number | string | null;
  resting_hr: number | string | null;
};

const ALGORITHM_VERSION = 'derived-metrics-v1';
const dayMs = 86_400_000;

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

const numeric = (value: number | string | null): number | null => {
  if (value === null) return null;
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const dateKey = (value: Date): string => value.toISOString().slice(0, 10);
const dateFromKey = (value: string): Date => new Date(`${value}T00:00:00.000Z`);
const round = (value: number): number => Math.round(value * 100) / 100;

const median = (values: number[]): number | null => {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
};

const calculateTrainingMetrics = (athleteId: string, activities: Activity[]) => {
  if (activities.length === 0) return [];
  const byDay = new Map<string, { load: number; ids: string[] }>();
  for (const activity of activities) {
    const load = numeric(activity.training_load);
    if (load === null || load < 0) continue;
    const day = activity.started_at.slice(0, 10);
    const current = byDay.get(day) ?? { load: 0, ids: [] };
    current.load += load;
    current.ids.push(activity.id);
    byDay.set(day, current);
  }
  if (byDay.size === 0) return [];

  const keys = [...byDay.keys()].sort();
  const first = dateFromKey(keys[0]);
  const last = dateFromKey(keys[keys.length - 1]);
  const dailyLoads: number[] = [];
  const ctlHistory: number[] = [];
  const rows: Json[] = [];
  let ctl = 0;
  let atl = 0;
  const ctlAlpha = 1 - Math.exp(-1 / 42);
  const atlAlpha = 1 - Math.exp(-1 / 7);

  for (let cursor = first; cursor <= last; cursor = new Date(cursor.getTime() + dayMs)) {
    const day = dateKey(cursor);
    const facts = byDay.get(day) ?? { load: 0, ids: [] };
    ctl += (facts.load - ctl) * ctlAlpha;
    atl += (facts.load - atl) * atlAlpha;
    dailyLoads.push(facts.load);
    ctlHistory.push(ctl);
    const load7 = dailyLoads.slice(-7).reduce((sum, value) => sum + value, 0);
    const load28 = dailyLoads.slice(-28).reduce((sum, value) => sum + value, 0);
    const priorCtl = ctlHistory.length > 7 ? ctlHistory[ctlHistory.length - 8] : ctlHistory[0];
    rows.push({
      athlete_id: athleteId,
      metric_date: day,
      daily_load: round(facts.load),
      load_7_day: round(load7),
      load_28_day: round(load28),
      chronic_training_load: round(ctl),
      acute_training_load: round(atl),
      training_stress_balance: round(ctl - atl),
      weekly_ctl_ramp: round(ctl - priorCtl),
      source_activity_ids: facts.ids,
      data_confidence: facts.ids.length > 0 ? 1 : 0.8,
      algorithm_version: ALGORITHM_VERSION,
      calculated_at: new Date().toISOString(),
    });
  }
  return rows;
};

const calculateBaseline = (athleteId: string, wellness: Wellness[]) => {
  if (wellness.length === 0) return null;
  const latestDate = wellness.map((row) => row.recorded_date).sort().at(-1)!;
  const cutoff = dateKey(new Date(dateFromKey(latestDate).getTime() - 27 * dayMs));
  const window = wellness.filter((row) => row.recorded_date >= cutoff);
  const hrv = window.map((row) => numeric(row.hrv_ms)).filter((value): value is number => value !== null && value > 0);
  const rhr = window.map((row) => numeric(row.resting_hr)).filter((value): value is number => value !== null && value > 0);
  const available = hrv.length + rhr.length;
  return {
    athlete_id: athleteId,
    baseline_date: latestDate,
    hrv_baseline_ms: median(hrv),
    resting_hr_baseline: median(rhr),
    hrv_sample_count: hrv.length,
    resting_hr_sample_count: rhr.length,
    source_observation_ids: window.map((row) => row.source_observation_id),
    data_confidence: Math.min(1, available / 28),
    algorithm_version: ALGORITHM_VERSION,
    calculated_at: new Date().toISOString(),
  };
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }
  try {
    const expected = requiredEnv('CYCLEREADY_SYNC_JOB_SECRET');
    if (request.headers.get('x-cycle-ready-sync-secret') !== expected) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const body = await request.json().catch(() => ({})) as Json;
    const supabase = createClient(
      requiredEnv('SUPABASE_URL'),
      requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false } },
    );
    let athleteQuery = supabase.from('athletes').select('id');
    if (typeof body.athlete_id === 'string') athleteQuery = athleteQuery.eq('id', body.athlete_id);
    const { data: athletes, error: athleteError } = await athleteQuery;
    if (athleteError) throw athleteError;
    const completed: Json[] = [];

    for (const athlete of athletes ?? []) {
      const idempotencyKey = typeof body.idempotency_key === 'string'
        ? `${body.idempotency_key}:${athlete.id}`
        : `${ALGORITHM_VERSION}:${athlete.id}:${dateKey(new Date())}`;
      const run = await supabase.from('metric_calculation_runs').upsert({
        athlete_id: athlete.id,
        metric_type: 'training_load_and_recovery_baselines',
        idempotency_key: idempotencyKey,
        algorithm_version: ALGORITHM_VERSION,
        status: 'running',
        source_references: [],
        output_references: [],
        started_at: new Date().toISOString(),
      }, { onConflict: 'athlete_id,metric_type,idempotency_key' }).select('id').single();
      if (run.error) throw run.error;

      try {
        const [activityResult, wellnessResult] = await Promise.all([
          supabase.from('activities').select('id,started_at,training_load')
            .eq('athlete_id', athlete.id).order('started_at'),
          supabase.from('daily_wellness_resolved')
            .select('source_observation_id,recorded_date,hrv_ms,resting_hr')
            .eq('athlete_id', athlete.id).order('recorded_date'),
        ]);
        if (activityResult.error) throw activityResult.error;
        if (wellnessResult.error) throw wellnessResult.error;
        const metricRows = calculateTrainingMetrics(athlete.id, activityResult.data as Activity[]);
        const baseline = calculateBaseline(athlete.id, wellnessResult.data as Wellness[]);
        await supabase.from('metric_calculation_runs').update({
          source_references: {
            activity_ids: (activityResult.data ?? []).map((row) => row.id),
            wellness_observation_ids: (wellnessResult.data ?? [])
              .map((row) => row.source_observation_id),
          },
        }).eq('id', run.data.id);
        if (metricRows.length > 0) {
          const result = await supabase.from('daily_training_metrics').upsert(metricRows, {
            onConflict: 'athlete_id,metric_date,algorithm_version',
          });
          if (result.error) throw result.error;
        }
        if (baseline) {
          const result = await supabase.from('athlete_metric_baselines').upsert(baseline, {
            onConflict: 'athlete_id,baseline_date,algorithm_version',
          });
          if (result.error) throw result.error;
        }
        const outputs = {
          daily_training_metrics: metricRows.length,
          baseline_date: baseline?.baseline_date ?? null,
        };
        await supabase.from('metric_calculation_runs').update({
          status: 'completed',
          output_references: outputs,
          completed_at: new Date().toISOString(),
        }).eq('id', run.data.id);
        completed.push({ athlete_id: athlete.id, ...outputs });
      } catch (error) {
        await supabase.from('metric_calculation_runs').update({
          status: 'failed',
          error_code: error instanceof Error ? error.message.slice(0, 240) : 'unknown_error',
          completed_at: new Date().toISOString(),
        }).eq('id', run.data.id);
        throw error;
      }
    }
    return Response.json({ algorithm_version: ALGORITHM_VERSION, completed });
  } catch (error) {
    console.error(error);
    return Response.json({
      error: error instanceof Error ? error.message : 'Unknown processing error',
    }, { status: 500 });
  }
});
