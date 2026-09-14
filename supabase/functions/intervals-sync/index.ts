import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

const optionalEnv = (name: string): string | null =>
  Deno.env.get(name)?.trim() || null;

const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0')).join('');
};

const numberValue = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) ? value : null;

const integerValue = (value: unknown): number | null => {
  const number = numberValue(value);
  return number === null ? null : Math.round(number);
};

const positiveValue = (value: unknown): number | null => {
  const number = numberValue(value);
  return number !== null && number > 0 ? number : null;
};

const tenPointValue = (value: unknown): number | null => {
  const number = numberValue(value);
  if (number === null) return null;
  return Math.max(0, Math.min(10, number > 10 ? number / 10 : number));
};

const activityRow = (athleteId: string, activity: Json) => ({
  athlete_id: athleteId,
  external_activity_id: String(activity.id),
  source: 'intervals_icu',
  started_at: activity.start_date ?? activity.start_date_local,
  sport: String(activity.type ?? 'cycling').toLowerCase(),
  duration_seconds: integerValue(activity.elapsed_time ?? activity.duration) ?? 0,
  moving_time_seconds: integerValue(activity.moving_time),
  distance_metres: numberValue(activity.distance),
  elevation_metres: numberValue(
    activity.total_elevation_gain ?? activity.elevation_gain,
  ),
  average_power: integerValue(activity.average_watts ?? activity.avg_watts),
  normalized_power: integerValue(
    activity.weighted_average_watts ?? activity.normalized_power,
  ),
  maximum_power: integerValue(activity.max_watts),
  average_hr: integerValue(activity.average_heartrate ?? activity.avg_hr),
  maximum_hr: integerValue(activity.max_heartrate ?? activity.max_hr),
  average_cadence: numberValue(activity.average_cadence),
  kilojoules: numberValue(activity.kilojoules) ??
    (numberValue(activity.joules) === null
      ? null
      : numberValue(activity.joules)! / 1000),
  training_load: numberValue(activity.icu_training_load ?? activity.training_load),
  rpe: numberValue(activity.icu_rpe ?? activity.rpe),
  notes: typeof activity.description === 'string' ? activity.description : null,
  source_payload: activity,
  imported_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
});

const wellnessRow = (athleteId: string, wellness: Json) => ({
  athlete_id: athleteId,
  recorded_date: String(wellness.id),
  hrv_ms: positiveValue(wellness.hrv),
  resting_hr: positiveValue(wellness.restingHR),
  sleep_minutes: integerValue(
    numberValue(wellness.sleepSecs) === null
      ? null
      : numberValue(wellness.sleepSecs)! / 60,
  ),
  sleep_quality: tenPointValue(wellness.sleepScore),
  fatigue: tenPointValue(wellness.fatigue),
  soreness: tenPointValue(wellness.soreness),
  stress: tenPointValue(wellness.stress),
  motivation: tenPointValue(wellness.motivation),
  weight_kg: numberValue(wellness.weight),
  illness_flag: wellness.sick === true,
  injury_or_pain_flag: wellness.injured === true,
  source: 'intervals_icu',
  source_payload: wellness,
  imported_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
});

const invokeProcessor = async (
  name: string,
  body: Json,
  jobSecret: string,
): Promise<Json> => {
  const response = await fetch(
    `${requiredEnv('SUPABASE_URL')}/functions/v1/${name}`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-cycle-ready-sync-secret': jobSecret,
      },
      body: JSON.stringify(body),
    },
  );
  const payload = await response.json().catch(() => ({})) as Json;
  if (!response.ok) {
    throw new Error(`${name} failed: ${payload.error ?? response.status}`);
  }
  return payload;
};

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') {
      return Response.json({ error: 'Method not allowed' }, { status: 405 });
    }
    const body = await request.json().catch(() => ({})) as Json;
    const jobSecret = requiredEnv('CYCLEREADY_SYNC_JOB_SECRET');
    const webhookSecret = Deno.env.get('INTERVALS_WEBHOOK_SECRET')?.trim();
    const suppliedJobSecret = request.headers.get('x-cycle-ready-sync-secret');
    const suppliedSchedulerSecret = request.headers.get(
      'x-cycle-ready-scheduler-secret',
    );
    const suppliedAuthorization = request.headers.get('authorization');
    const suppliedWebhookSecret = typeof body.secret === 'string' ? body.secret : null;
    const supabase = createClient(
      requiredEnv('SUPABASE_URL'),
      requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false } },
    );
    let scheduledRequest = false;
    if (suppliedSchedulerSecret) {
      const scheduler = await supabase.from('integration_scheduler_authorization')
        .select('secret_digest').eq('id', true).maybeSingle();
      if (scheduler.error) throw scheduler.error;
      scheduledRequest = scheduler.data?.secret_digest ===
        await sha256(suppliedSchedulerSecret);
    }
    if (suppliedJobSecret !== jobSecret &&
        !scheduledRequest &&
        (!webhookSecret ||
          (suppliedWebhookSecret !== webhookSecret &&
            suppliedAuthorization !== `Bearer ${webhookSecret}`))) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const webhookAthlete = typeof body.athlete_id === 'string'
      ? body.athlete_id
      : typeof body.athlete === 'object' && body.athlete !== null &&
          'id' in body.athlete
      ? String((body.athlete as Json).id)
      : null;
    let providerAthleteId = webhookAthlete ?? optionalEnv('INTERVALS_ICU_ATHLETE_ID');
    let integrationQuery = supabase.from('integrations')
      .select('id, athlete_id, provider_athlete_id').eq('provider', 'intervals_icu');
    if (providerAthleteId) {
      integrationQuery = integrationQuery.eq('provider_athlete_id', providerAthleteId);
    }
    const integrationResult = await integrationQuery.limit(2);
    if (integrationResult.error) throw integrationResult.error;
    if ((integrationResult.data?.length ?? 0) > 1) {
      throw new Error('Intervals.icu request does not identify exactly one athlete');
    }
    let integration = integrationResult.data?.[0] ?? null;
    if (!integration) {
      throw new Error(
        'Intervals.icu athlete has not completed account-specific authorization',
      );
    }
    providerAthleteId = integration.provider_athlete_id ?? providerAthleteId;
    if (!providerAthleteId) {
      throw new Error('Intervals.icu athlete identity is missing');
    }
    const credentialResult = await supabase.from('provider_credentials')
      .select('access_token, token_type').eq('integration_id', integration.id)
      .maybeSingle();
    if (credentialResult.error) throw credentialResult.error;
    const oauthToken = credentialResult.data?.access_token as string | undefined;
    const apiKey = optionalEnv('INTERVALS_ICU_API_KEY');
    if (!oauthToken && !apiKey) {
      throw new Error('Intervals.icu has no server credential');
    }

    const newest = typeof body.newest === 'string'
      ? body.newest
      : new Date().toISOString().slice(0, 10);
    const oldest = typeof body.oldest === 'string'
      ? body.oldest
      : new Date(Date.now() - 14 * 86400000).toISOString().slice(0, 10);
    const runKey = `intervals_icu:${oldest}:${newest}`;
    const syncRun = await supabase.from('integration_sync_runs').upsert({
      athlete_id: integration.athlete_id,
      integration_id: integration.id,
      provider: 'intervals_icu',
      idempotency_key: runKey,
      trigger_type: suppliedJobSecret === jobSecret || scheduledRequest
        ? 'scheduled_or_manual'
        : 'webhook',
      requested_window: { oldest, newest },
      status: 'running',
      started_at: new Date().toISOString(),
    }, { onConflict: 'athlete_id,provider,idempotency_key' }).select('id').single();
    if (syncRun.error) throw syncRun.error;
    const apiAthleteId = oauthToken ? '0' : providerAthleteId;
    const url = new URL(
      `https://intervals.icu/api/v1/athlete/${encodeURIComponent(apiAthleteId)}/activities`,
    );
    url.searchParams.set('oldest', oldest);
    url.searchParams.set('newest', newest);
    const authorization = oauthToken
      ? `${credentialResult.data?.token_type ?? 'Bearer'} ${oauthToken}`
      : `Basic ${btoa(`API_KEY:${apiKey}`)}`;
    const response = await fetch(url, {
      headers: { Authorization: authorization },
    });
    if (!response.ok) {
      throw new Error(`Intervals.icu returned ${response.status}`);
    }
    const activities = await response.json() as Json[];
    const valid = activities.filter((activity) =>
      activity.id != null && (activity.start_date ?? activity.start_date_local) != null
    );
    if (valid.length > 0) {
      const { error } = await supabase.from('activities')
        .upsert(valid.map((activity) => activityRow(integration.athlete_id, activity)), {
          onConflict: 'athlete_id,source,external_activity_id',
        });
      if (error) throw error;
    }
    const wellnessUrl = new URL(
      `https://intervals.icu/api/v1/athlete/${encodeURIComponent(apiAthleteId)}/wellness`,
    );
    wellnessUrl.searchParams.set('oldest', oldest);
    wellnessUrl.searchParams.set('newest', newest);
    const wellnessResponse = await fetch(wellnessUrl, {
      headers: { Authorization: authorization },
    });
    if (!wellnessResponse.ok) {
      throw new Error(`Intervals.icu wellness returned ${wellnessResponse.status}`);
    }
    const wellness = (await wellnessResponse.json() as Json[]).filter((record) =>
      typeof record.id === 'string'
    );
    if (wellness.length > 0) {
      const { error } = await supabase.from('wellness')
        .upsert(wellness.map((record) => wellnessRow(integration.athlete_id, record)), {
          onConflict: 'athlete_id,recorded_date,source',
        });
      if (error) throw error;
    }
    await supabase.from('integrations').update({
      connection_status: 'connected',
      last_sync_at: new Date().toISOString(),
      sync_error: null,
    }).eq('id', integration.id);
    const processingBody = {
      athlete_id: integration.athlete_id,
      oldest,
      date: newest,
      planning_date: newest,
      idempotency_key: runKey,
    };
    const processing: Json = {};
    for (const step of [
      { name: 'process-derived-metrics', key: 'process-derived-metrics' },
      { name: 'process-session-analysis', key: 'process-session-analysis' },
      { name: 'process-session-analysis', key: 'process-session-recovery', mode: 'recovery' },
      { name: 'process-athlete-capabilities', key: 'process-athlete-capabilities' },
      { name: 'process-readiness', key: 'process-readiness' },
      { name: 'process-goal-plan', key: 'process-goal-plan' },
      { name: 'process-adaptive-decision', key: 'process-adaptive-decision' },
    ]) {
      try {
        processing[step.key] = await invokeProcessor(
          step.name,
          step.mode ? { ...processingBody, mode: step.mode } : processingBody,
          jobSecret,
        );
      } catch (error) {
        processing[step.key] = {
          error: error instanceof Error ? error.message : 'processor_failed',
        };
      }
    }
    const processingFailed = Object.values(processing).some((result) =>
      typeof result === 'object' && result !== null && 'error' in result
    );
    await supabase.from('integration_sync_runs').update({
      imported_counts: {
        activities: valid.length,
        wellness: wellness.length,
      },
      status: processingFailed ? 'imported_processing_partial' : 'completed',
      error_code: processingFailed ? 'downstream_processor_failed' : null,
      completed_at: new Date().toISOString(),
    }).eq('id', syncRun.data.id);
    return Response.json({
      activities_imported: valid.length,
      wellness_imported: wellness.length,
      oldest,
      newest,
      processing,
    });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error
      ? error.message
      : typeof error === 'object' && error !== null && 'message' in error
      ? String(error.message)
      : 'Unknown sync error';
    return Response.json(
      { error: message },
      { status: 500 },
    );
  }
});
