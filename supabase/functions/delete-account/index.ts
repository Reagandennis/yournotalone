// Deletes the calling user's account and everything attached to it.
//
// The user id is taken from the verified JWT, never from the request body,
// so this can only ever delete the caller's own account.
//
// Order matters: storage objects are removed first (they are not covered by
// the foreign-key cascade), then a Sign in with Apple user's access is
// revoked with Apple (App Store guideline 5.1.1(v)), then the auth user —
// which cascades through journal_entries, mood_entries, therapy_requests,
// recovery_habits, recovery_pledges, craving_logs, deletion_requests and
// apple_refresh_tokens.
//
// Deploy:  supabase functions deploy delete-account
// Secrets: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY — see
//          ../_shared/apple.ts. Without them Apple users are still deleted,
//          just not revoked with Apple.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { appleConfigured, revokeRefreshToken } from '../_shared/apple.ts';

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

  // Verify the caller and get their id from the token itself.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  try {
    // 1. Avatars live at <user-id>/… in a public bucket and are not
    //    reachable by the cascade.
    const { data: files } = await admin.storage.from('avatars').list(user.id);
    if (files?.length) {
      await admin.storage
        .from('avatars')
        .remove(files.map((file) => `${user.id}/${file.name}`));
    }

    // 2. Close out the request before the row disappears with the user, so
    //    a backup restore still shows what happened and when.
    await admin
      .from('deletion_requests')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('user_id', user.id)
      .eq('status', 'pending');

    // 3. Revoke Sign in with Apple. Best-effort: Apple being unreachable
    //    must not keep someone's data around against their wishes, so a
    //    failure is logged for a manual revoke rather than thrown.
    const { data: appleToken } = await admin
      .from('apple_refresh_tokens')
      .select('refresh_token')
      .eq('user_id', user.id)
      .maybeSingle();
    if (appleToken) {
      if (!appleConfigured()) {
        console.error('delete-account: Apple token not revoked, APPLE_* secrets missing', user.id);
      } else {
        try {
          await revokeRefreshToken(appleToken.refresh_token);
        } catch (error) {
          console.error('delete-account: Apple revoke failed', user.id, error);
        }
      }
    }

    // 4. The auth user. Everything else cascades from here.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json({ deleted: true });
  } catch (error) {
    // Leave the request 'pending' so it stays in the manual work queue.
    console.error('delete-account failed', user.id, error);
    return json({ error: 'deletion_failed' }, 500);
  }
});
