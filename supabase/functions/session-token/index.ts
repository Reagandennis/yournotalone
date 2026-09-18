// Issues a LiveKit access token for one therapy session.
//
// Only two people can get one: the client who booked the session and the
// therapist it was assigned to. The session has to be confirmed, paid for
// (or free), and close to its start time. Every check runs against the
// database here, so the app can't talk its way into a call.
//
// Deploy:  supabase functions deploy session-token
// Secrets: LIVEKIT_URL         wss://<project>.livekit.cloud
//          LIVEKIT_API_KEY     LiveKit Cloud → Settings → Keys
//          LIVEKIT_API_SECRET
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL');
const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET');

// Keep in step with sessionEarlyJoin and sessionLateGrace in
// lib/therapy/therapy_repository.dart.
const EARLY_JOIN_MS = 10 * 60 * 1000;
const LATE_GRACE_MS = 30 * 60 * 1000;

const SETTLED_PAYMENTS = ['not_required', 'paid', 'waived'];

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// A LiveKit access token is an HS256 JWT signed with the API secret.
async function signToken(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = base64url(encoder.encode(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${body}`));
  return `${header}.${body}.${base64url(new Uint8Array(signature))}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!LIVEKIT_URL || !LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
    console.error('session-token: LiveKit secrets are not set');
    return json({ error: 'not_configured' }, 503);
  }

  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'missing_token' }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  let requestId = '';
  try {
    const body = await req.json();
    requestId = typeof body?.request_id === 'string' ? body.request_id : '';
  } catch {
    // Falls through to the check below.
  }
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return json({ error: 'bad_request' }, 400);

  const { data: session, error: sessionError } = await admin
    .from('therapy_requests')
    .select(
      'id, user_id, therapist_id, status, scheduled_at, duration_minutes, payment_status',
    )
    .eq('id', requestId)
    .maybeSingle();
  if (sessionError) {
    console.error('session-token: lookup failed', requestId, sessionError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (!session) return json({ error: 'not_found' }, 404);

  // Who is asking? Anyone else gets the same answer as a missing session.
  let role: 'client' | 'therapist' | null = null;
  let identity = '';
  let name = '';
  if (session.user_id === user.id) {
    role = 'client';
    identity = `client-${user.id}`;
    const fullName = String(user.user_metadata?.full_name ?? '').trim();
    name = fullName.split(/\s+/)[0] || 'Client';
  } else if (session.therapist_id && user.email && user.email_confirmed_at) {
    const { data: account } = await admin
      .from('therapist_accounts')
      .select('email')
      .eq('therapist_id', session.therapist_id)
      .maybeSingle();
    if (account && account.email === user.email.toLowerCase()) {
      const { data: therapist } = await admin
        .from('therapists')
        .select('full_name')
        .eq('id', session.therapist_id)
        .maybeSingle();
      role = 'therapist';
      identity = `therapist-${session.therapist_id}`;
      name = therapist?.full_name ?? 'Therapist';
    }
  }
  if (!role) return json({ error: 'not_found' }, 404);

  if (session.status !== 'confirmed' || !session.scheduled_at) {
    return json({ error: 'not_confirmed' }, 409);
  }
  if (!SETTLED_PAYMENTS.includes(session.payment_status)) {
    return json({ error: 'payment_required' }, 402);
  }

  const start = Date.parse(session.scheduled_at);
  const end = start + session.duration_minutes * 60 * 1000;
  const now = Date.now();
  if (now < start - EARLY_JOIN_MS) {
    return json({ error: 'too_early', opens_at: new Date(start - EARLY_JOIN_MS).toISOString() }, 425);
  }
  if (now > end + LATE_GRACE_MS) return json({ error: 'session_over' }, 410);

  const room = `therapy-${session.id}`;
  const accessToken = await signToken(
    {
      iss: LIVEKIT_API_KEY,
      sub: identity,
      name,
      nbf: Math.floor(now / 1000) - 10,
      exp: Math.floor((end + LATE_GRACE_MS) / 1000),
      metadata: JSON.stringify({ role }),
      video: {
        room,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    },
    LIVEKIT_API_SECRET,
  );

  // Who actually turned up. A token is only handed out inside the call
  // window to someone tapping Join, so this is the server's best view of
  // attendance; close_out_elapsed_sessions (0016) decides from it what an
  // unfinished session becomes.
  const joinedColumn = role === 'client' ? 'client_joined_at' : 'therapist_joined_at';
  const { error: joinError } = await admin
    .from('therapy_requests')
    .update({ [joinedColumn]: new Date(now).toISOString() })
    .eq('id', session.id)
    .is(joinedColumn, null);
  if (joinError) console.error('session-token: recording join failed', session.id, joinError);

  return json({
    url: LIVEKIT_URL,
    token: accessToken,
    room,
    identity,
    role,
    ends_at: new Date(end).toISOString(),
  });
});
