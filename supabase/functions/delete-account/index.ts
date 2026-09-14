import { createClient } from 'npm:@supabase/supabase-js@2';

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }
  const bearer = request.headers.get('authorization')
    ?.replace(/^Bearer\s+/i, '').trim();
  if (!bearer) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const url = requiredEnv('SUPABASE_URL');
  const userClient = createClient(url, requiredEnv('SUPABASE_ANON_KEY'), {
    auth: { persistSession: false },
  });
  const authenticated = await userClient.auth.getUser(bearer);
  const user = authenticated.data.user;
  if (authenticated.error || !user) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const service = createClient(url, requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false },
  });
  const deleted = await service.auth.admin.deleteUser(user.id);
  if (deleted.error) {
    console.error({ code: deleted.error.code, status: deleted.error.status });
    return Response.json({ error: 'Account deletion failed' }, { status: 500 });
  }
  return Response.json({ deleted: true });
});
