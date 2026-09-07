// Deletes the calling user's account and everything attached to it.
//
// The user id is taken from the verified JWT, never from the request body,
// so this can only ever delete the caller's own account.
//
// Order matters: storage objects are removed first (they are not covered by
// the foreign-key cascade), then the auth user — which cascades through
// journal_entries, mood_entries, therapy_requests, recovery_habits,
// recovery_pledges, craving_logs and deletion_requests.
//
// Deploy:  supabase functions deploy delete-account
// It needs no extra secrets: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are
// injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';

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

    // 3. The auth user. Everything else cascades from here.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json({ deleted: true });
  } catch (error) {
    // Leave the request 'pending' so it stays in the manual work queue.
    console.error('delete-account failed', user.id, error);
    return json({ error: 'deletion_failed' }, 500);
  }
});
