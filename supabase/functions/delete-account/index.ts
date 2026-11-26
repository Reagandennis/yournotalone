// Deletes the calling user's account and everything attached to it.
//
// The user id is taken from the verified JWT, never from the request body,
// so this can only ever delete the caller's own account.
//
// Order matters: storage objects are removed first (they are not covered by
// the foreign-key cascade): the avatar (avatars/<uid>/…), the therapist
// profile photo (therapist-photos/self/<uid>/…, 0028; a therapist profile
// still pointing at it loses its photo_url) and the identity documents
// (therapist-kyc/<uid>/…, 0029/0033) of an applicant who was never approved
// or was declined. An approved therapist's KYC documents stay: the
// therapist profile, its licence expiry and therapist_documents (0033)
// outlive the account and rest on them. Folders are listed a page at a time
// and walked into, as list() returns at most a page per call. A storage
// failure stops the deletion (the request goes back to 'pending' for the
// manual queue) rather than leave files behind unnoticed. Then a Sign in
// with Apple user's access is revoked with Apple (App Store guideline
// 5.1.1(v)), then sessions still to come are cancelled (the therapist
// hears, a paid one goes to the care team for its refund), then the auth user — which cascades through
// journal_entries, mood_entries, recovery_habits, recovery_pledges,
// craving_logs, deletion_requests and apple_refresh_tokens. Sessions and
// Paystack checkouts stay, without the user and their words (0035): what a
// therapist is owed and the purchase records are kept.
//
// Deploy:  supabase functions deploy delete-account
// Secrets: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY — see
//          ../_shared/apple.ts. Without them Apple users are still deleted,
//          just not revoked with Apple.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { appleConfigured, revokeRefreshToken } from '../_shared/apple.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const PAGE = 1000;

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

// Every object under `prefix` in `bucket`, subfolders included. list()
// gives one page of one folder; a folder comes back as an entry with no id.
async function listAll(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const paths: string[] = [];
  for (let offset = 0; ; offset += PAGE) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: PAGE,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) throw error;
    for (const entry of data ?? []) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id === null || entry.id === undefined) {
        paths.push(...await listAll(admin, bucket, path));
      } else {
        paths.push(path);
      }
    }
    if (!data || data.length < PAGE) return paths;
  }
}

async function removeAll(admin: SupabaseClient, bucket: string, prefix: string) {
  const paths = await listAll(admin, bucket, prefix);
  // remove() takes a batch at a time too.
  for (let i = 0; i < paths.length; i += PAGE) {
    const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + PAGE));
    if (error) throw error;
  }
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

  // The requests this call closed out, to reopen if the deletion fails.
  let closedRequests: string[] = [];

  try {
    // 1. Files, which the cascade can't reach. Avatars live at
    //    <user-id>/… in a public bucket; therapist photos at
    //    self/<user-id>/… (0028).
    await removeAll(admin, 'avatars', user.id);
    await removeAll(admin, 'therapist-photos', `self/${user.id}`);
    const { error: photoError } = await admin
      .from('therapists')
      .update({ photo_url: null })
      .like('photo_url', `%/therapist-photos/self/${user.id}/%`);
    if (photoError) throw photoError;

    //    KYC documents at <user-id>/… (0029), unless this is an approved
    //    therapist: their profile and its licence checks outlive the
    //    account (therapist_documents, 0033, keeps pointing at them).
    const { data: approved, error: approvedError } = await admin
      .from('therapist_applications')
      .select('id')
      .eq('user_id', user.id)
      .eq('status', 'approved')
      .limit(1);
    if (approvedError) throw approvedError;
    let isTherapist = (approved?.length ?? 0) > 0;
    if (!isTherapist && user.email) {
      const { data: account, error: accountError } = await admin
        .from('therapist_accounts')
        .select('therapist_id')
        .eq('email', user.email.toLowerCase())
        .maybeSingle();
      if (accountError) throw accountError;
      isTherapist = account !== null;
    }
    if (!isTherapist) await removeAll(admin, 'therapist-kyc', user.id);

    // 2. Close out the request before the row disappears with the user, so
    //    a backup restore still shows what happened and when. Reopened
    //    below if the deletion then fails.
    const { data: closed, error: closeError } = await admin
      .from('deletion_requests')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .select('id');
    if (closeError) throw closeError;
    closedRequests = (closed ?? []).map((row) => row.id as string);

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

    // 4. Sessions still to come, while the client's details are there for
    //    the emails. Before 0035 is applied the function doesn't exist;
    //    the deletion goes ahead regardless.
    const { error: cancelError } = await admin.rpc('therapy_cancel_for_deletion', {
      p_user_id: user.id,
    });
    if (cancelError) {
      console.error('delete-account: sessions not cancelled first', user.id, cancelError);
    }

    // 5. The auth user. Everything else cascades from here.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json({ deleted: true });
  } catch (error) {
    // Put the request back to 'pending' so it stays in the manual work
    // queue (supabase/account_ops.sql, section 2).
    console.error('delete-account failed', user.id, error);
    if (closedRequests.length > 0) {
      const { error: reopenError } = await admin
        .from('deletion_requests')
        .update({ status: 'pending', completed_at: null })
        .in('id', closedRequests);
      if (reopenError) {
        console.error('delete-account: request not reopened', user.id, closedRequests, reopenError);
      }
    }
    return json({ error: 'deletion_failed' }, 500);
  }
});
