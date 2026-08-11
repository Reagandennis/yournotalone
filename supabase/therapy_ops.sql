-- Day-to-day therapy-request operations. Paste the piece you need into
-- the Supabase dashboard → SQL Editor (runs as postgres, bypasses RLS).
-- The app shows the user "Request received" while status = 'pending',
-- "Session confirmed" (+ time) once confirmed, and moves it to past
-- requests when completed or cancelled.

-- ── 1. Inbox: open requests, oldest first, with contact details ──
select
  r.created_at,
  u.email,
  u.raw_user_meta_data ->> 'full_name' as name,
  r.topic,
  array_to_string(r.availability, ' · ') as availability,
  r.note,
  r.is_free_session,
  r.status,
  r.scheduled_at,
  r.id
from public.therapy_requests r
join auth.users u on u.id = r.user_id
where r.status in ('pending', 'confirmed')
order by r.created_at;

-- ── 2. Confirm: after agreeing a time with the user by email ─────
-- Include the timezone offset (e.g. +03 for Nairobi); the app shows
-- the time converted to the user's device timezone.
-- update public.therapy_requests
-- set status = 'confirmed', scheduled_at = '2026-08-12 14:00+03'
-- where id = '<request id from query 1>';

-- ── 3. Complete: after the session happened ──────────────────────
-- update public.therapy_requests
-- set status = 'completed'
-- where id = '<request id>';

-- ── 4. Cancel from your side (no-show, unreachable, etc.) ────────
-- Note: this frees the free-session offer again — the app treats
-- "every request cancelled" as still eligible.
-- update public.therapy_requests
-- set status = 'cancelled'
-- where id = '<request id>';

-- ── 5. Check the automatic notification emails went out ──────────
-- Each new request triggers an email via Brevo (migration 0004).
-- pg_net records the API responses here; status 201 = accepted.
select id, status_code, content, created
from net._http_response
order by created desc
limit 10;
