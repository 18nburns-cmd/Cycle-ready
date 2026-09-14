import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  DAILY_COACHING_CONTRACT_VERSION,
  parseDailyCoachingRequest,
} from '../_shared/daily-coaching-contract.ts';

type Json = Record<string, unknown>;
const MODEL_VERSION = 'daily-coaching-orchestrator-v1.0.0';

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0')).join('');
};

const runStage = async (name: string, payload: Json): Promise<Json> => {
  const response = await fetch(`${requiredEnv('SUPABASE_URL')}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-cycle-ready-sync-secret': requiredEnv('CYCLEREADY_SYNC_JOB_SECRET'),
    },
    body: JSON.stringify(payload),
  });
  const result = await response.json().catch(() => ({})) as Json;
  if (!response.ok) throw new Error(`${name} failed: ${String(result.error ?? response.status)}`);
  return result;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }
  let runTracker: {
    client: ReturnType<typeof createClient>;
    id: string;
    attempt: number;
  } | null = null;
  try {
    const supabase = createClient(
      requiredEnv('SUPABASE_URL'),
      requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false } },
    );
    const syncAuthorized = request.headers.get('x-cycle-ready-sync-secret') ===
      requiredEnv('CYCLEREADY_SYNC_JOB_SECRET');
    const schedulerSecret = request.headers.get('x-cycle-ready-scheduler-secret');
    let schedulerAuthorized = false;
    if (schedulerSecret) {
      const stored = await supabase.from('integration_scheduler_authorization')
        .select('secret_digest').eq('id', true).maybeSingle();
      if (stored.error) throw stored.error;
      schedulerAuthorized = stored.data?.secret_digest === await sha256(schedulerSecret);
    }
    const bearer = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '').trim();
    const authenticated = bearer
      ? await createClient(
        requiredEnv('SUPABASE_URL'),
        requiredEnv('SUPABASE_ANON_KEY'),
        { auth: { persistSession: false } },
      ).auth.getUser(bearer)
      : null;
    const authenticatedUserId = authenticated?.data.user?.id ?? null;
    if (!syncAuthorized && !schedulerAuthorized && !authenticatedUserId) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const envelope = parseDailyCoachingRequest(await request.json());
    if (authenticatedUserId) {
      const owned = await supabase.from('athletes').select('id')
        .eq('id', envelope.athlete_id)
        .eq('user_id', authenticatedUserId)
        .maybeSingle();
      if (owned.error) throw owned.error;
      if (!owned.data) {
        return Response.json({ error: 'Athlete does not belong to authenticated user' }, { status: 403 });
      }
    }
    const latestRun = await supabase.from('daily_coaching_runs')
      .select('attempt_number')
      .eq('athlete_id', envelope.athlete_id)
      .eq('coaching_date', envelope.coaching_date)
      .order('attempt_number', { ascending: false }).limit(1).maybeSingle();
    if (latestRun.error) throw latestRun.error;
    const previousAttempt = Number(latestRun.data?.attempt_number ?? 0);
    if (previousAttempt >= 10) {
      return Response.json({ error: 'Daily coaching retry limit reached' }, { status: 429 });
    }
    const attempt = previousAttempt + 1;
    const started = await supabase.from('daily_coaching_runs').insert({
      athlete_id: envelope.athlete_id,
      coaching_date: envelope.coaching_date,
      timezone: envelope.timezone,
      attempt_number: attempt,
      status: 'RUNNING',
      model_version: MODEL_VERSION,
    }).select('id').single();
    if (started.error) throw started.error;
    runTracker = { client: supabase, id: started.data.id, attempt };
    const stageInput = {
      athlete_id: envelope.athlete_id,
      date: envelope.coaching_date,
    };

    // Readiness must be current before candidate selection and safety policy.
    const readiness = await runStage('process-readiness', stageInput);
    const context = await supabase.rpc('assemble_daily_coaching_context', {
      requested_athlete_id: envelope.athlete_id,
      requested_date: envelope.coaching_date,
    });
    if (context.error) throw context.error;

    const contextPayload = context.data as Json;
    const evidence = contextPayload.evidence as Json;
    const fingerprint = await sha256(JSON.stringify({
      planned_workout: contextPayload.planned_workout ?? null,
      evidence,
    }));
    const previous = await supabase.from('daily_coaching_recommendations')
      .select('recommendation,evidence_fingerprint')
      .eq('athlete_id', envelope.athlete_id)
      .eq('coaching_date', envelope.coaching_date)
      .maybeSingle();
    if (previous.error) throw previous.error;
    if (previous.data?.evidence_fingerprint === fingerprint) {
      await supabase.from('daily_coaching_runs').update({
        status: 'COMPLETED', completed_at: new Date().toISOString(),
      }).eq('id', runTracker.id);
      return Response.json({ ...(previous.data.recommendation as Json), reused: true });
    }

    const adaptive = await runStage('process-adaptive-decision', stageInput);

    const decisions = Array.isArray(adaptive.decisions) ? adaptive.decisions as Json[] : [];
    const decision = decisions[0] ?? {};
    const generatedAt = new Date().toISOString();
    const output = {
      contract_version: DAILY_COACHING_CONTRACT_VERSION,
      athlete_id: envelope.athlete_id,
      coaching_date: envelope.coaching_date,
      idempotency_key: `${envelope.athlete_id}:${envelope.coaching_date}:${MODEL_VERSION}`,
      status: 'COMPLETED',
      athlete_state: String(evidence.illness_symptoms === true ? 'RED' : 'AVAILABLE'),
      data_confidence: Number(evidence.readiness ?? 50) === 50 ? 'LOW' : 'HIGH',
      decision: String(decision.decision ?? 'KEEP'),
      selected_workout: decision.replacement_workout ??
        (context.data as Json).planned_workout ?? null,
      readiness: Number(evidence.readiness ?? 50),
      reason_codes: Array.isArray(decision.reason_codes) ? decision.reason_codes : [],
      explanation: String(decision.explanation ??
        'No planned workout required an adaptive change.'),
      next_72h_effect: 'Future sessions remain governed by the active training block.',
      confidence: Number(decision.confidence ?? .45),
      evidence_snapshot: evidence,
      model_version: MODEL_VERSION,
      generated_at: generatedAt,
      stages: { readiness_model: readiness.algorithm_version, adaptive_model: adaptive.coaching_model_version },
    };
    const persisted = await supabase.from('daily_coaching_recommendations').upsert({
      athlete_id: envelope.athlete_id,
      coaching_date: envelope.coaching_date,
      idempotency_key: output.idempotency_key,
      status: output.status,
      input_snapshot: context.data,
      evidence_snapshot: evidence,
      evidence_fingerprint: fingerprint,
      recommendation: output,
      model_version: MODEL_VERSION,
      generated_at: generatedAt,
    }, { onConflict: 'athlete_id,coaching_date' });
    if (persisted.error) throw persisted.error;
    const completed = await supabase.from('daily_coaching_runs').update({
      status: 'COMPLETED', completed_at: new Date().toISOString(),
      next_retry_at: null, error_code: null, error_message: null,
    }).eq('id', runTracker.id);
    if (completed.error) throw completed.error;
    return Response.json(output);
  } catch (error) {
    console.error(error);
    if (runTracker) {
      const delayMinutes = Math.min(60, 5 * 2 ** (runTracker.attempt - 1));
      const nextRetry = new Date(Date.now() + delayMinutes * 60000).toISOString();
      await runTracker.client.from('daily_coaching_runs').update({
        status: 'FAILED',
        error_code: error instanceof Error ? error.name : 'UNKNOWN',
        error_message: error instanceof Error
          ? error.message.slice(0, 500)
          : 'Unknown daily coaching error',
        completed_at: new Date().toISOString(),
        next_retry_at: nextRetry,
      }).eq('id', runTracker.id);
    }
    return Response.json(
      { error: error instanceof Error ? error.message : 'Unknown daily coaching error' },
      { status: 500 },
    );
  }
});
