-- Manual account-deletion operations — the fallback for when the
-- `delete-account` Edge Function couldn't finish (no network on the user's
-- side, function not deployed, service outage).
--
-- Paste the piece you need into the Supabase dashboard → SQL Editor, which
-- runs as postgres and bypasses RLS. See supabase/migrations/0006 for the
-- table, and supabase/functions/delete-account for the automatic path.

-- ── 1. The queue: requests the function never closed out ─────────
select
  r.requested_at,
  coalesce(r.user_email, u.email) as email,
  u.raw_user_meta_data ->> 'full_name' as name,
  r.status,
  r.user_id,
  r.id
from public.deletion_requests r
left join auth.users u on u.id = r.user_id
where r.status = 'pending'
order by r.requested_at;

-- ── 2. What would go, for one user (check before deleting) ───────
-- select
--   (select count(*) from public.journal_entries  where user_id = '<user id>') as journal_entries,
--   (select count(*) from public.mood_entries     where user_id = '<user id>') as mood_entries,
--   (select count(*) from public.recovery_habits  where user_id = '<user id>') as habits,
--   (select count(*) from public.recovery_pledges where user_id = '<user id>') as pledges,
--   (select count(*) from public.craving_logs     where user_id = '<user id>') as craving_logs,
--   (select count(*) from public.therapy_requests where user_id = '<user id>') as therapy_requests,
--   (select count(*) from storage.objects
--      where bucket_id = 'avatars'
--        and (storage.foldername(name))[1] = '<user id>')                      as avatars;

-- ── 3. Delete: avatar objects first, then the auth user ──────────
-- Everything else cascades from auth.users. Run both statements together.
--
-- delete from storage.objects
--  where bucket_id = 'avatars'
--    and (storage.foldername(name))[1] = '<user id>';
--
-- update public.deletion_requests
--    set status = 'completed', completed_at = now()
--  where user_id = '<user id>' and status = 'pending';
--
-- delete from auth.users where id = '<user id>';

-- ── 4. A request that must not proceed (e.g. it was disputed) ────
-- update public.deletion_requests
--    set status = 'failed', completed_at = now()
--  where id = '<request id>';
