-- Day-to-day therapy operations. Most of this is done in the app now —
-- Settings → Care team dashboard — so these are for what the app doesn't
-- cover, and for checking on things. Paste the piece you need into the
-- Supabase dashboard → SQL Editor (runs as postgres, bypasses RLS).
--
-- A request's life: pending ("Request received") → confirmed, once matched
-- with a therapist and a time → completed, once the therapist finishes it;
-- or cancelled. Paid sessions also move unpaid → paid (or waived).

-- ── 1. Inbox: open requests, oldest first ──────────────────────────
select
  r.created_at,
  u.email,
  u.raw_user_meta_data ->> 'full_name' as name,
  r.topic,
  array_to_string(r.availability, ' · ') as availability,
  r.note,
  r.status,
  t.full_name as therapist,
  r.scheduled_at,
  r.is_free_session,
  r.payment_status,
  r.id
from public.therapy_requests r
join auth.users u on u.id = r.user_id
left join public.therapists t on t.id = r.therapist_id
where r.status in ('pending', 'confirmed')
order by r.created_at;

-- ── 2. Admins: who can open the care team dashboard ────────────────
-- An address works as soon as someone signs in with it and confirms it.
-- select email from public.admins;
-- insert into public.admins (email) values ('someone@example.com');
-- delete from public.admins where email = 'someone@example.com';

-- ── 3. Therapists and whether they've signed in ────────────────────
select t.full_name, ta.email, t.active,
       exists (select 1 from auth.users u
               where lower(u.email) = ta.email
                 and u.email_confirmed_at is not null) as signed_in
from public.therapists t
left join public.therapist_accounts ta on ta.therapist_id = t.id
order by t.active desc, t.full_name;

-- ── 4. Payments taken outside the app ──────────────────────────────
-- The dashboard's "Mark as paid" / "Waive fee" do this; kept here for bulk
-- fixes. Only sessions with a price can be changed.
-- update public.therapy_requests
-- set payment_status = 'paid', paid_at = now(),
--     payment_ref = 'manual:<note, e.g. mpesa code>'
-- where id = '<request id>' and price_cents > 0;

-- ── 5. Ratings, and every safety concern raised ────────────────────
select r.scheduled_at, t.full_name as therapist,
       rt.author_role, rt.rating, rt.comment, rt.flags, r.id
from public.therapy_ratings rt
join public.therapy_requests r on r.id = rt.request_id
left join public.therapists t on t.id = r.therapist_id
order by ('safety_concern' = any(rt.flags)) desc, rt.created_at desc
limit 50;

-- ── 6. Check the automatic emails went out ─────────────────────────
-- Requests, matches, cancellations, therapist invites and safety flags all
-- email through Resend (migrations 0008 and 0009). pg_net records the API
-- responses here; status 200 = accepted. A 403 usually means the sender
-- address isn't on a domain verified in Resend.
select id, status_code, content, created
from net._http_response
order by created desc
limit 10;
