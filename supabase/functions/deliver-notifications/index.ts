import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@6';

type Json = Record<string, unknown>;

const env = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

const digest = async (value: string): Promise<string> => {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
};

const accessToken = async (): Promise<string> => {
  const clientEmail = env('FIREBASE_CLIENT_EMAIL');
  const privateKey = await importPKCS8(
    env('FIREBASE_PRIVATE_KEY').replaceAll('\\n', '\n'),
    'RS256',
  );
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }).setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`Firebase authorization returned ${response.status}`);
  return String((await response.json()).access_token);
};

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const supabase = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
    const supplied = request.headers.get('x-cycle-ready-scheduler-secret') ?? '';
    const authorization = await supabase.from('integration_scheduler_authorization')
      .select('secret_digest').eq('id', true).maybeSingle();
    if (authorization.error) throw authorization.error;
    if (!supplied || await digest(supplied) !== authorization.data?.secret_digest) {
      return new Response('Unauthorized', { status: 401 });
    }

    const due = await supabase.from('notifications').select('*')
      .is('delivered_at', null).lte('scheduled_for', new Date().toISOString())
      .order('created_at').limit(100);
    if (due.error) throw due.error;
    if (!due.data?.length) return Response.json({ delivered: 0, failed: 0 });

    const bearer = await accessToken();
    const projectId = env('FIREBASE_PROJECT_ID');
    let delivered = 0;
    let failed = 0;
    for (const notification of due.data) {
      const tokens = await supabase.from('device_push_tokens').select('id, token')
        .eq('athlete_id', notification.athlete_id);
      if (tokens.error) throw tokens.error;
      let sent = false;
      for (const device of tokens.data ?? []) {
        const payload = notification.payload as Json;
        const route = typeof payload?.route === 'string' ? payload.route : '/';
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
          {
            method: 'POST',
            headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: {
              token: device.token,
              notification: { title: notification.title, body: notification.body },
              data: {
                notification_id: String(notification.id),
                title: String(notification.title),
                body: String(notification.body),
                route,
              },
              android: { priority: 'high' },
            } }),
          },
        );
        if (response.ok) {
          sent = true;
        } else {
          failed++;
          const body = await response.text();
          if (response.status === 404 || body.includes('UNREGISTERED')) {
            await supabase.from('device_push_tokens').delete().eq('id', device.id);
          }
        }
      }
      if (sent) {
        const update = await supabase.from('notifications')
          .update({ delivered_at: new Date().toISOString() }).eq('id', notification.id);
        if (update.error) throw update.error;
        delivered++;
      }
    }
    return Response.json({ delivered, failed });
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'Notification delivery failed' }, { status: 500 });
  }
});
