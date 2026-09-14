import { createClient } from 'npm:@supabase/supabase-js@2';

type Json = Record<string, unknown>;

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

const message = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

const description = (payload: Json): string => {
  const minutes = Number(payload.duration_minutes ?? 0);
  switch (String(payload.session_type ?? 'endurance')) {
    case 'intervals':
      return 'Warm-up\n- 15m 60%\n\n4x\n- 8m 102%\n- 4m 50%\n\nCool-down\n- 10m 55%';
    case 'tempo':
      return 'Warm-up\n- 15m 60%\n\n3x\n- 12m 91%\n- 5m 50%\n\nCool-down\n- 10m 55%';
    case 'recovery':
      return `- ${minutes}m 50%`;
    default:
      return `- ${minutes}m 66%`;
  }
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }
  const supabase = createClient(
    requiredEnv('SUPABASE_URL'),
    requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false } },
  );
  try {
    const supplied = request.headers.get('x-cycle-ready-scheduler-secret');
    const scheduler = await supabase.from('integration_scheduler_authorization')
      .select('secret_digest').eq('id', true).maybeSingle();
    if (scheduler.error) throw scheduler.error;
    if (!supplied || scheduler.data?.secret_digest !== await sha256(supplied)) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const claimed = await supabase.rpc('claim_workout_delivery_jobs', {
      p_limit: 10,
    });
    if (claimed.error) throw claimed.error;
    const results: Json[] = [];
    for (const job of claimed.data ?? []) {
      try {
        if (job.provider !== 'intervals-icu') {
          throw new Error(`Unsupported workout provider: ${job.provider}`);
        }
        const deliveryResult = await supabase.from('workout_deliveries')
          .select('id,planned_session_id,desired_content_hash,desired_version')
          .eq('id', job.delivery_id).single();
        if (deliveryResult.error) throw deliveryResult.error;
        const integrationResult = await supabase.from('integrations')
          .select('id,provider_athlete_id').eq('athlete_id', job.athlete_id)
          .eq('provider', 'intervals_icu').single();
        if (integrationResult.error) throw integrationResult.error;
        const credentialResult = await supabase.from('provider_credentials')
          .select('access_token,token_type').eq(
            'integration_id',
            integrationResult.data.id,
          ).single();
        if (credentialResult.error) throw credentialResult.error;
        const authorization =
          `${credentialResult.data.token_type ?? 'Bearer'} ${credentialResult.data.access_token}`;
        // The phone and server must address the same Intervals event. The
        // calendar date is unique per athlete in CycleReady, so keep this ID
        // stable even when an adaptive-plan regeneration replaces the local
        // planned_sessions row (and therefore its UUID).
        const scheduledDate = String((job.payload as Json).scheduled_date);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduledDate)) {
          throw new Error('Workout delivery payload has no valid scheduled_date');
        }
        const externalId = `cycleready-${scheduledDate}`;
        const legacyExternalId = String(deliveryResult.data.planned_session_id);
        let providerWorkoutId: string | null = null;
        let response: Response;
        if (job.operation === 'delete') {
          response = await fetch(
            'https://intervals.icu/api/v1/athlete/0/events/bulk-delete',
            {
              method: 'PUT',
              headers: { Authorization: authorization, 'content-type': 'application/json' },
              // Delete both the canonical event and the UUID used by worker
              // versions before v2. Repeating this request is harmless.
              body: JSON.stringify([
                { external_id: externalId },
                { external_id: legacyExternalId },
              ]),
            },
          );
        } else {
          const payload = job.payload as Json;
          // Remove the legacy UUID-keyed event before the canonical upsert.
          // This repairs existing duplicate calendars and remains idempotent
          // when the job is retried.
          const cleanup = await fetch(
            'https://intervals.icu/api/v1/athlete/0/events/bulk-delete',
            {
              method: 'PUT',
              headers: { Authorization: authorization, 'content-type': 'application/json' },
              body: JSON.stringify([{ external_id: legacyExternalId }]),
            },
          );
          if (!cleanup.ok) {
            const cleanupBody = await cleanup.text().catch(() => '');
            throw new Error(
              `Intervals.icu legacy cleanup returned ${cleanup.status}: ${cleanupBody.slice(0, 500)}`,
            );
          }
          response = await fetch(
            'https://intervals.icu/api/v1/athlete/0/events/bulk?upsert=true',
            {
              method: 'POST',
              headers: { Authorization: authorization, 'content-type': 'application/json' },
              body: JSON.stringify([{
                category: 'WORKOUT',
                type: 'Ride',
                start_date_local:
                  `${payload.scheduled_date}T${payload.scheduled_start_time ?? '09:00:00'}`,
                name: `CycleReady - ${payload.purpose ?? payload.session_type ?? 'Workout'}`,
                description: description(payload),
                planned_duration: Number(payload.duration_minutes ?? 0) * 60,
                target: 'POWER',
                external_id: externalId,
              }]),
            },
          );
        }
        const responseBody = await response.json().catch(() => null);
        if (!response.ok) {
          throw new Error(
            `Intervals.icu returned ${response.status}: ${JSON.stringify(responseBody).slice(0, 500)}`,
          );
        }
        if (Array.isArray(responseBody) && responseBody[0]?.id != null) {
          providerWorkoutId = String(responseBody[0].id);
        }
        const completedAt = new Date().toISOString();
        const outboxUpdate = await supabase.from('workout_delivery_outbox')
          .update({ status: 'completed', completed_at: completedAt, last_error: null })
          .eq('id', job.id).eq('status', 'processing');
        if (outboxUpdate.error) throw outboxUpdate.error;
        const deliveryUpdate: Json = {
          delivery_status: job.operation === 'create'
            ? 'delivered'
            : job.operation === 'update' ? 'updated' : 'deleted',
          acknowledged_content_hash: job.content_hash,
          acknowledged_version: deliveryResult.data.desired_version,
          attempt_count: job.attempt_count,
          last_attempt_at: completedAt,
          failure_message: null,
        };
        if (providerWorkoutId) deliveryUpdate.external_workout_id = providerWorkoutId;
        const update = await supabase.from('workout_deliveries')
          .update(deliveryUpdate).eq('id', job.delivery_id)
          .eq('desired_content_hash', job.content_hash);
        if (update.error) throw update.error;
        results.push({ id: job.id, status: 'completed' });
      } catch (error) {
        const failure = message(error).slice(0, 1000);
        const attempts = Number(job.attempt_count ?? 1);
        const retrySeconds = Math.min(3600, 30 * 2 ** Math.min(attempts - 1, 7));
        await supabase.from('workout_delivery_outbox').update({
          status: 'failed',
          last_error: failure,
          next_attempt_at: new Date(Date.now() + retrySeconds * 1000).toISOString(),
        }).eq('id', job.id).eq('status', 'processing');
        await supabase.from('workout_deliveries').update({
          delivery_status: 'failed',
          attempt_count: attempts,
          last_attempt_at: new Date().toISOString(),
          failure_message: failure,
        }).eq('id', job.delivery_id).eq('desired_content_hash', job.content_hash);
        results.push({ id: job.id, status: 'failed', error: failure });
      }
    }
    return Response.json({ processed: results.length, results });
  } catch (error) {
    console.error(error);
    return Response.json({ error: message(error) }, { status: 500 });
  }
});
