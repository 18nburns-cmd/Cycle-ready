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

const page = (title: string, message: string, status = 200) =>
  new Response(`<!doctype html><html><head><meta name="viewport" content="width=device-width"><title>${title}</title></head><body style="font-family:system-ui;max-width:42rem;margin:4rem auto;padding:1rem"><h1>${title}</h1><p>${message}</p><p>You can close this page and return to CycleReady.</p></body></html>`, {
    status,
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' },
  });

Deno.serve(async (request) => {
  try {
    if (request.method !== 'GET') return page('Connection failed', 'Method not allowed.', 405);
    const requestUrl = new URL(request.url);
    if (requestUrl.searchParams.get('error')) {
      return page('Connection cancelled', 'Intervals.icu access was not granted.', 400);
    }
    const code = requestUrl.searchParams.get('code');
    const state = requestUrl.searchParams.get('state');
    if (!code || !state) return page('Connection failed', 'The authorization response was incomplete.', 400);

    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const service = createClient(
      supabaseUrl,
      requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false } },
    );
    const stateHash = await sha256(state);
    const consumed = await service.from('oauth_authorization_states').update({
      consumed_at: new Date().toISOString(),
    }).eq('state_hash', stateHash).eq('provider', 'intervals_icu')
      .is('consumed_at', null).gt('expires_at', new Date().toISOString())
      .select('athlete_id').maybeSingle();
    if (consumed.error) throw consumed.error;
    if (!consumed.data) return page('Connection failed', 'This link has expired or was already used. Start again in CycleReady.', 400);

    const callback = `${supabaseUrl}/functions/v1/intervals-oauth-callback`;
    const tokenResponse = await fetch('https://intervals.icu/api/oauth/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: requiredEnv('INTERVALS_CLIENT_ID'),
        client_secret: requiredEnv('INTERVALS_CLIENT_SECRET'),
        code,
        redirect_uri: callback,
      }),
    });
    const token = await tokenResponse.json().catch(() => ({})) as Json;
    if (!tokenResponse.ok || typeof token.access_token !== 'string') {
      throw new Error(`Intervals.icu token exchange failed (${tokenResponse.status})`);
    }
    const athletePayload = token.athlete as Json | undefined;
    const providerAthleteId = athletePayload?.id == null
      ? null
      : String(athletePayload.id);
    if (!providerAthleteId) throw new Error('Intervals.icu did not identify the athlete');
    const integration = await service.from('integrations').upsert({
      athlete_id: consumed.data.athlete_id,
      provider: 'intervals_icu',
      provider_athlete_id: providerAthleteId,
      connection_status: 'connected',
      authorization_method: 'oauth',
      sync_error: null,
    }, { onConflict: 'athlete_id,provider' }).select('id').single();
    if (integration.error) throw integration.error;
    const scopes = typeof token.scope === 'string'
      ? token.scope.split(',').map((scope) => scope.trim()).filter(Boolean)
      : [];
    const credential = await service.from('provider_credentials').upsert({
      integration_id: integration.data.id,
      athlete_id: consumed.data.athlete_id,
      provider: 'intervals_icu',
      access_token: token.access_token,
      token_type: typeof token.token_type === 'string' ? token.token_type : 'Bearer',
      scopes,
    }, { onConflict: 'integration_id' });
    if (credential.error) throw credential.error;
    return page('Intervals.icu connected', 'CycleReady can now synchronize your training and wellness data securely.');
  } catch (error) {
    console.error(error);
    return page('Connection failed', 'CycleReady could not complete the connection. Please start again from the app.', 500);
  }
});
