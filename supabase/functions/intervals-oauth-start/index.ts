import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, apikey, content-type',
};

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

const randomState = (): string => {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    if (request.method !== 'POST') {
      return Response.json({ error: 'Method not allowed' }, {
        status: 405,
        headers: corsHeaders,
      });
    }
    const authorization = request.headers.get('authorization');
    if (!authorization?.startsWith('Bearer ')) {
      return Response.json({ error: 'Sign in to CycleReady first.' }, {
        status: 401,
        headers: corsHeaders,
      });
    }
    const url = requiredEnv('SUPABASE_URL');
    const userClient = createClient(url, requiredEnv('SUPABASE_ANON_KEY'), {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return Response.json({ error: 'CycleReady session is no longer valid.' }, {
        status: 401,
        headers: corsHeaders,
      });
    }
    const service = createClient(url, requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), {
      auth: { persistSession: false },
    });
    const athlete = await service.from('athletes').select('id')
      .eq('user_id', userData.user.id).single();
    if (athlete.error) throw athlete.error;

    const state = randomState();
    const stateHash = await sha256(state);
    await service.from('oauth_authorization_states').delete()
      .eq('athlete_id', athlete.data.id).eq('provider', 'intervals_icu');
    const stored = await service.from('oauth_authorization_states').insert({
      state_hash: stateHash,
      athlete_id: athlete.data.id,
      provider: 'intervals_icu',
      expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
    });
    if (stored.error) throw stored.error;

    const callback = `${url}/functions/v1/intervals-oauth-callback`;
    const consent = new URL('https://intervals.icu/oauth/authorize');
    consent.searchParams.set('client_id', requiredEnv('INTERVALS_CLIENT_ID'));
    consent.searchParams.set('redirect_uri', callback);
    consent.searchParams.set(
      'scope',
      'ACTIVITY:READ,WELLNESS:READ,CALENDAR:WRITE,SETTINGS:READ',
    );
    consent.searchParams.set('state', state);
    return Response.json({ authorization_url: consent.toString() }, {
      headers: { ...corsHeaders, 'cache-control': 'no-store' },
    });
  } catch (error) {
    console.error(error);
    return Response.json({
      error: error instanceof Error ? error.message : 'OAuth start failed',
    }, { status: 500, headers: corsHeaders });
  }
});
