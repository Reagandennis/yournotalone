// Keeps the Sign in with Apple refresh token for the calling user.
//
// Called by the app right after an Apple sign-in with the one-time
// authorization code (valid for five minutes). The code is swapped for a
// refresh token, which delete-account later revokes with Apple — an App
// Store requirement for apps offering Sign in with Apple. See migration
// 0020_apple_refresh_tokens.sql.
//
// Deploy:  supabase functions deploy apple-token
// Secrets: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY — see
//          ../_shared/apple.ts.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { appleConfigured, exchangeAuthorizationCode } from '../_shared/apple.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'missing_token' }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // The user id comes from the verified JWT, never from the body.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  const body = await req.json().catch(() => ({}));
  const code = body?.authorizationCode;
  if (typeof code !== 'string' || !code) {
    return json({ error: 'missing_authorization_code' }, 400);
  }

  if (!appleConfigured()) {
    console.error('apple-token: APPLE_* secrets are not set');
    return json({ error: 'apple_not_configured' }, 503);
  }

  try {
    const refreshToken = await exchangeAuthorizationCode(code);
    const { error } = await admin.from('apple_refresh_tokens').upsert({
      user_id: user.id,
      refresh_token: refreshToken,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    return json({ stored: true });
  } catch (error) {
    console.error('apple-token failed', user.id, error);
    return json({ error: 'exchange_failed' }, 502);
  }
});
