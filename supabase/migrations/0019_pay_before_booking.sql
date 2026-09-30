-- Pay before booking.
--
-- Until now a request went to the care team as soon as it was sent, the
-- first session was free, and a paid session was paid for only after the
-- match. People booked, were matched, and never turned up — therapists set
-- time aside for nothing. From now on:
--
--   • A request from the app is saved as a draft (status awaiting_payment)
--     that nobody but its owner sees. The care team is told about it, and
--     the request emails go out, only once the session has been paid for:
--     the confirm-session-payment Edge Function (or an admin recording a
--     payment or waiving the fee) moves it to pending. Every session costs
--     the same; there is no free first session any more.
--   • The moment a payment is recorded the client is emailed a receipt,
--     which also spells out the cancellation and missed-session policy.
--   • A session can be cancelled from the app up to 24 hours before it
--     starts — the care team is emailed to refund it. Later than that it
--     can't be cancelled in the app, and a session the client doesn't
--     join is completed as a no-show and not refunded: the 0016 sweep
--     now emails the client and queues a phone notification saying so.
--   • Drafts that are never paid for are cancelled by the same sweep
--     after 24 hours, so they don't pile up.
--
-- Builds on 0008 (request emails), 0009/0011 (insert rules), 0010
-- (notifications), 0015 (cancel rules) and 0016 (the sweep).
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then redeploy:
--   supabase functions deploy confirm-session-payment
-- (it must accept a draft as payable).

-- ── Schema ───────────────────────────────────────────────────────────

alter table public.therapy_requests
  drop constraint if exists therapy_requests_status_check;
alter table public.therapy_requests
  add constraint therapy_requests_status_check
  check (status in ('awaiting_payment', 'pending', 'confirmed', 'completed', 'cancelled'));

-- When the request actually reached the care team (paid, or fee waived).
-- Null for a draft, and for a draft that was discarded or expired.
alter table public.therapy_requests
  add column if not exists submitted_at timestamptz;
update public.therapy_requests
  set submitted_at = created_at
  where submitted_at is null and status <> 'awaiting_payment';

alter table public.app_notifications
  drop constraint if exists app_notifications_kind_check;
alter table public.app_notifications
  add constraint app_notifications_kind_check
  check (kind in (
    'session_booked', 'session_changed', 'session_cancelled',
    'session_reminder', 'session_missed'
  ));

-- How far ahead a session can still be cancelled from the app, with a
-- refund. Keep in step with therapyCancelNotice in
-- lib/therapy/therapy_repository.dart.
create or replace function public.therapy_cancel_notice()
returns interval
language sql
immutable
set search_path = ''
as $$
  select interval '24 hours';
$$;

-- ── Policies ─────────────────────────────────────────────────────────

drop policy if exists "Users create own therapy requests" on public.therapy_requests;
create policy "Users create own therapy requests"
  on public.therapy_requests for insert
  with check (auth.uid() = user_id and status = 'awaiting_payment');

drop policy if exists "Users cancel own therapy requests" on public.therapy_requests;
create policy "Users cancel own therapy requests"
  on public.therapy_requests for update
  using (auth.uid() = user_id
         and status in ('awaiting_payment', 'pending', 'confirmed'))
  with check (auth.uid() = user_id and status = 'cancelled');

-- ── Insert: a draft, priced, waiting to be paid ──────────────────────

-- Same as in 0011, except that a request from the app starts as a draft,
-- every session is priced (no free first one), the daily cap counts
-- submitted requests rather than drafts, and a new draft replaces any
-- older unpaid one.
create or replace function public.therapy_requests_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.topic := trim(new.topic);
  new.note := nullif(trim(new.note), '');

  if current_user in ('anon', 'authenticated') then
    new.status := 'awaiting_payment';
    new.therapist_id := null;
    new.scheduled_at := null;
    new.duration_minutes := 50;
    new.payment_ref := null;
    new.paid_at := null;
    new.confirmed_at := null;
    new.completed_at := null;
    new.cancelled_at := null;
    new.client_summary := null;
    new.close_reason := null;
    new.submitted_at := null;
    new.payment_status := 'unpaid';
    new.created_at := now();

    perform pg_advisory_xact_lock(
      hashtext('therapy_requests:' || new.user_id::text));

    if exists (
      select 1 from public.therapy_requests r
      where r.user_id = new.user_id
        and r.status in ('pending', 'confirmed')
    ) then
      raise exception 'You already have a session on the way. Cancel it first if you need to change something.'
        using errcode = 'P0001';
    end if;

    if (
      select count(*) from public.therapy_requests r
      where r.user_id = new.user_id
        and r.submitted_at > now() - interval '24 hours'
    ) >= public.therapy_requests_daily_limit() then
      raise exception 'That''s as many requests as we can take in a day. Please try again tomorrow, or reply to our email if it''s urgent.'
        using errcode = 'P0001';
    end if;

    -- Drafts are cheap, but not free to make without limit.
    if (
      select count(*) from public.therapy_requests r
      where r.user_id = new.user_id
        and r.created_at > now() - interval '24 hours'
    ) >= public.therapy_requests_daily_limit() * 4 then
      raise exception 'That''s as many requests as we can take in a day. Please try again tomorrow, or reply to our email if it''s urgent.'
        using errcode = 'P0001';
    end if;

    if public.therapy_requests_last_hour()
       >= public.therapy_requests_hourly_limit() then
      raise warning 'therapy requests: hourly limit reached, refusing user %',
        new.user_id;
      raise exception 'We''re getting a lot of requests right now. Please try again in a little while.'
        using errcode = 'P0001';
    end if;

    -- The newest draft is the one they mean; an older unpaid one goes.
    -- A purchase that was meant for it is never lost: the Edge Function
    -- attaches the oldest unused purchase to whichever draft is paid next.
    update public.therapy_requests
    set status = 'cancelled'
    where user_id = new.user_id and status = 'awaiting_payment';
  end if;

  -- Every session is priced. Only the dashboard (which bypasses the block
  -- above) can insert one with the fee already waived.
  new.is_free_session := false;
  new.price_cents := public.therapy_session_price_cents();
  new.currency := 'USD';
  if new.payment_status not in ('paid', 'waived') then
    new.payment_status := 'unpaid';
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_before_insert on public.therapy_requests;
create trigger therapy_requests_before_insert
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_before_insert();

-- ── Update: payment sends a draft on; cancelling needs notice ────────

-- Same as in 0015, plus: a payment (or a waiver) arriving on a draft moves
-- it to pending, whoever recorded it. From the app, a draft or a pending
-- request can be cancelled at any time, a confirmed session only until
-- 24 hours before it starts. Being paid no longer blocks cancelling —
-- the care team is emailed to refund it (notify_therapy_refund_due).
create or replace function public.therapy_requests_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.scheduled_at is distinct from old.scheduled_at then
    new.reminder_sent_at := null;
  end if;
  if old.status = 'awaiting_payment'
     and new.status = 'awaiting_payment'
     and new.payment_status in ('paid', 'waived')
     and old.payment_status not in ('paid', 'waived') then
    new.status := 'pending';
    new.submitted_at := coalesce(new.submitted_at, now());
  end if;
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if new.status is distinct from 'cancelled'
     or old.status not in ('awaiting_payment', 'pending', 'confirmed') then
    raise exception 'Only cancelling is possible from the app.'
      using errcode = '42501';
  end if;
  if old.status = 'confirmed'
     and old.scheduled_at is not null
     and old.scheduled_at - public.therapy_cancel_notice() <= now() then
    raise exception 'Sessions can be cancelled in the app up to 24 hours before they start. After that, reply to your booking email — a session that''s missed or cancelled late isn''t refunded.'
      using errcode = 'P0001';
  end if;
  new := old;
  new.status := 'cancelled';
  new.cancelled_at := now();
  return new;
end;
$$;

drop trigger if exists therapy_requests_before_update on public.therapy_requests;
create trigger therapy_requests_before_update
  before update on public.therapy_requests
  for each row execute function public.therapy_requests_before_update();

-- ── The request emails, now sent when the request is paid for ────────

-- Replaces 0008's version: same two emails (care team, client), written
-- for a request that is already paid, and sent from the moment it reaches
-- the care team rather than from the insert.
create or replace function public.notify_therapy_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  spacer constant text := '<div style="height:12px;font-size:0;line-height:0;">&nbsp;</div>';
  user_email text;
  user_name text;
  first_name text;
  display_name text;
  availability text;
  requested_at text;
  reply_by text;
  payment_text text;
  price text;
begin
  select u.email::text,
         nullif(trim(regexp_replace(
           coalesce(u.raw_user_meta_data ->> 'full_name',
                    u.raw_user_meta_data ->> 'name', ''),
           '\s+', ' ', 'g')), '')
    into user_email, user_name
    from auth.users u
    where u.id = new.user_id;
  first_name := split_part(user_name, ' ', 1);
  display_name := coalesce(user_name, user_email, 'Someone');

  availability := coalesce(
    nullif(array_to_string(new.availability, ' · '), ''),
    'Flexible'
  );
  requested_at := to_char(coalesce(new.submitted_at, now()) at time zone 'Africa/Nairobi',
    'Dy FMDD Mon YYYY, HH24:MI') || ' Nairobi time';
  reply_by := to_char(
    (coalesce(new.submitted_at, now()) + interval '24 hours') at time zone 'Africa/Nairobi',
    'Dy FMDD Mon, HH24:MI') || ' Nairobi time';
  price := '$' || (new.price_cents / 100);
  payment_text := case new.payment_status
    when 'paid' then price || ' — paid in the app'
    when 'waived' then 'Fee waived by the care team'
    else price || ' — not paid'
  end;

  -- ── 1. To the care team ────────────────────────────────────────
  perform public.send_app_email(
    care_team,
    user_email,
    'Therapy request — ' || display_name,
    public.email_layout(
      public.email_escape(display_name) || ' · ' || public.email_escape(new.topic),
      'New therapy request',
      '<strong style="font-weight:600;color:#191919;">'
        || public.email_escape(display_name)
        || '</strong> has paid for a session and would like to talk to a '
        || 'therapist. They’ve been told we’ll connect them within 24 hours — by '
        || '<strong style="font-weight:600;color:#191919;">'
        || reply_by || '</strong>.',
      public.email_box('#F3F6FC', 'Request details',
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Name', public.email_escape(coalesce(user_name, '—')))
        || public.email_row('Email', case when user_email is null then '—'
             else '<a href="mailto:' || public.email_escape(user_email)
               || '" style="color:#3764CD;text-decoration:none;">'
               || public.email_escape(user_email) || '</a>' end)
        || public.email_row('Focus', public.email_escape(new.topic))
        || public.email_row('Availability', public.email_escape(availability))
        || public.email_row('Payment', public.email_escape(payment_text))
        || case when new.note is null then ''
             else public.email_row('Note',
               replace(public.email_escape(new.note), E'\n', '<br>')) end
        || public.email_row('Requested', requested_at)
        || public.email_row('Request ID',
             '<span style="font-family:Menlo,Consolas,monospace;font-size:12px;color:#6E6E73;">'
             || new.id || '</span>')
        || '</table>')
      || spacer
      || public.email_box('#F6F6F6', 'Next step',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Open <strong style="font-weight:600;color:#191919;">Settings → Care team</strong> '
        || 'in the app to match them with a therapist and a time. They’re emailed '
        || 'the details and join the video call from the app. Reply to this email '
        || 'to reach them directly.</div>'),
      'Sent automatically when someone books a therapist in the Δεν είσαι μόνος app.'
    ),
    'New therapy request'
      || E'\n\n'
      || 'Name: ' || coalesce(user_name, '—') || E'\n'
      || 'Email: ' || coalesce(user_email, '—') || E'\n'
      || 'Would like help with: ' || new.topic || E'\n'
      || 'Availability: ' || availability || E'\n'
      || 'Payment: ' || payment_text
      || coalesce(E'\n' || 'Note: ' || new.note, '')
      || E'\n' || 'Requested: ' || requested_at
      || E'\n\n'
      || 'They’ve been told we’ll connect them within 24 hours — by '
      || reply_by || '.'
      || E'\n\n'
      || 'Match them with a therapist from Settings → Care team in the app. '
      || 'Reply to this email to reach them directly (request id ' || new.id || ').',
    'therapy-request/' || new.id || '/care-team'
  );

  -- ── 2. To the client ───────────────────────────────────────────
  -- What they asked for and what happens next. Their note stays out of
  -- it: it's theirs, and inboxes get read over shoulders. The receipt is
  -- a separate email (notify_therapy_payment_received).
  perform public.send_app_email(
    user_email,
    care_team,
    'We’ve received your request',
    public.email_layout(
      'We’ll connect you with a licensed therapist within 24 hours.',
      'We’ve received your request',
      'Hi ' || public.email_escape(coalesce(first_name, 'there'))
        || ', thank you for reaching out — that takes courage. Your payment '
        || 'is in and your request is with our care team. We’ll connect you '
        || 'with a licensed therapist within '
        || '<strong style="font-weight:600;color:#191919;">24 hours</strong>, '
        || 'by email.',
      public.email_box('#F3F6FC', 'Your request',
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Focus', public.email_escape(new.topic))
        || public.email_row('Availability', public.email_escape(availability))
        || public.email_row('Payment', public.email_escape(payment_text))
        || '</table>')
      || $html$
<div style="padding:30px 0 14px;font-size:16px;font-weight:600;color:#191919;">What happens next</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">1</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">We match you</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">Our care team finds a licensed therapist for what you shared, usually within 24 hours.</div></td>
</tr>
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">2</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">You see your booking</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">Your therapist and session time appear in the app, and we email them to you. Can’t make it? Reply at least 24 hours before and we’ll move it.</div></td>
</tr>
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">3</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">You talk</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">A private video call, right in the app. What you say stays between you and them.</div></td>
</tr>
</table>
<div style="height:8px;font-size:0;line-height:0;">&nbsp;</div>
$html$
      || public.email_box('#FFF8E6', 'Cancellations and missed sessions',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'You can cancel in the app up to 24 hours before your session '
        || 'and we’ll refund you in full. Need a different time? Reply to '
        || 'your booking email at least 24 hours before and we’ll rebook '
        || 'you. A session that’s cancelled later than that, or that you '
        || 'don’t join, is not refunded — your therapist has set that '
        || 'time aside for you.</div>')
      || spacer
      || public.email_box('#F6F6F6', 'In crisis or immediate danger?',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Please don’t wait for us. Call your local emergency number — '
        || '112 in Greece and across the EU, 999 in Kenya and the UK, 911 in '
        || 'the US — or tap <strong style="font-weight:600;color:#191919;">'
        || 'Get help now</strong> in the app for crisis lines near you.</div>'),
      'Questions, or something’s changed? Just reply — this email comes '
        || 'straight to our care team.<br>You’re receiving this because you '
        || 'booked a therapist in the Δεν είσαι μόνος app.'
    ),
    'Hi ' || coalesce(first_name, 'there') || ','
      || E'\n\n'
      || 'Thank you for reaching out — that takes courage. Your payment is '
      || 'in and your request is with our care team. We’ll connect you with '
      || 'a licensed therapist within 24 hours, by email.'
      || E'\n\n'
      || 'Your request' || E'\n'
      || 'Focus: ' || new.topic || E'\n'
      || 'Availability: ' || availability || E'\n'
      || 'Payment: ' || payment_text
      || E'\n\n'
      || 'What happens next' || E'\n'
      || '1. We match you — our care team finds a licensed therapist for '
      || 'what you shared, usually within 24 hours.' || E'\n'
      || '2. You see your booking — your therapist and session time appear '
      || 'in the app, and we email them to you.' || E'\n'
      || '3. You talk — a private video call, right in the app.'
      || E'\n\n'
      || 'Cancellations and missed sessions: you can cancel in the app up to '
      || '24 hours before your session for a full refund, or reply to your '
      || 'booking email at least 24 hours before to move it. A session '
      || 'cancelled later than that, or not joined, is not refunded.'
      || E'\n\n'
      || 'In crisis or immediate danger? Please don’t wait for us. Call '
      || 'your local emergency number (112 in Greece and across the EU, 999 '
      || 'in Kenya and the UK, 911 in the US) or tap Get help now in the app.'
      || E'\n\n'
      || 'Questions, or something’s changed? Just reply to this email.'
      || E'\n\n'
      || '— Δεν είσαι μόνος',
    'therapy-request/' || new.id || '/user'
  );

  return new;
exception when others then
  raise warning 'therapy request % email failed: %', new.id, sqlerrm;
  return new;
end;
$$;

-- Fires when the request reaches the care team: on the payment that moves
-- a draft to pending, or on an insert that is already pending (only the
-- dashboard or a security-definer function can do that).
drop trigger if exists therapy_request_notify on public.therapy_requests;
create trigger therapy_request_notify
  after insert on public.therapy_requests
  for each row
  when (new.status = 'pending')
  execute function public.notify_therapy_request();

drop trigger if exists therapy_request_submitted_notify on public.therapy_requests;
create trigger therapy_request_submitted_notify
  after update on public.therapy_requests
  for each row
  when (old.status = 'awaiting_payment' and new.status = 'pending')
  execute function public.notify_therapy_request();

-- ── The receipt ──────────────────────────────────────────────────────

create or replace function public.notify_therapy_payment_received()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  spacer constant text := '<div style="height:12px;font-size:0;line-height:0;">&nbsp;</div>';
  client_email text;
  client_first text;
  amount text;
  paid_on text;
  method text;
  reference text;
  receipt_no text;
begin
  select u.email::text into client_email
    from auth.users u where u.id = new.user_id;
  client_first := public.therapy_client_first_name(new.user_id);
  amount := 'US$' || to_char(new.price_cents / 100.0, 'FM999990.00');
  paid_on := to_char(coalesce(new.paid_at, now()) at time zone 'UTC',
    'FMDD Mon YYYY, HH24:MI') || ' UTC';
  method := case
    when new.payment_ref like 'revenuecat:%' then 'In-app purchase (Google Play)'
    when new.payment_ref like 'manual:%' then 'Recorded by the care team'
    else 'In-app purchase'
  end;
  reference := coalesce(new.payment_ref, new.id::text);
  receipt_no := upper(left(replace(new.id::text, '-', ''), 10));

  perform public.send_app_email(
    client_email,
    care_team,
    'Your receipt — therapy session, ' || amount,
    public.email_layout(
      'Receipt ' || receipt_no || ' · ' || amount,
      'Thank you — here’s your receipt',
      'Hi ' || public.email_escape(coalesce(client_first, 'there'))
        || ', we’ve received your payment for one therapy session. Keep '
        || 'this email as your receipt.',
      public.email_box('#F3F6FC', 'Receipt ' || receipt_no,
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Item', 'One private session with a licensed therapist ('
             || new.duration_minutes || ' minutes)')
        || public.email_row('Amount', '<strong style="font-weight:600;color:#191919;">'
             || amount || '</strong>')
        || public.email_row('Paid on', paid_on)
        || public.email_row('Paid with', method)
        || public.email_row('Reference',
             '<span style="font-family:Menlo,Consolas,monospace;font-size:12px;color:#6E6E73;">'
             || public.email_escape(reference) || '</span>')
        || public.email_row('Focus', public.email_escape(new.topic))
        || '</table>')
      || spacer
      || public.email_box('#F6F6F6', 'What happens next',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Our care team matches you with a licensed therapist and a time, '
        || 'usually within 24 hours, and emails you the details. You join '
        || 'the video call from <strong style="font-weight:600;color:#191919;">'
        || 'Talk to a therapist</strong> in the app.</div>')
      || spacer
      || public.email_box('#FFF8E6', 'Cancellations and missed sessions',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || '<strong style="font-weight:600;color:#191919;">Full refund</strong> '
        || 'if you cancel in the app up to 24 hours before your session, or '
        || 'if we or your therapist have to cancel.<br>'
        || '<strong style="font-weight:600;color:#191919;">Free rebooking</strong> '
        || 'if you reply to your booking email at least 24 hours before to '
        || 'ask for a different time.<br>'
        || '<strong style="font-weight:600;color:#191919;">No refund</strong> '
        || 'for a session cancelled with less than 24 hours’ notice, or one '
        || 'you don’t join — your therapist has set that time aside for '
        || 'you.</div>'),
      'Issued by Δεν είσαι μόνος for a therapy session booked in the app. '
        || 'Google Play also emails its own order confirmation. Questions '
        || 'about this payment? Just reply to this email.'
    ),
    'Hi ' || coalesce(client_first, 'there') || ','
      || E'\n\n'
      || 'We’ve received your payment for one therapy session. Keep this '
      || 'email as your receipt.'
      || E'\n\n'
      || 'Receipt ' || receipt_no || E'\n'
      || 'Item: One private session with a licensed therapist ('
      || new.duration_minutes || ' minutes)' || E'\n'
      || 'Amount: ' || amount || E'\n'
      || 'Paid on: ' || paid_on || E'\n'
      || 'Paid with: ' || method || E'\n'
      || 'Reference: ' || reference || E'\n'
      || 'Focus: ' || new.topic
      || E'\n\n'
      || 'What happens next: our care team matches you with a licensed '
      || 'therapist and a time, usually within 24 hours, and emails you the '
      || 'details. You join the video call from Talk to a therapist in the app.'
      || E'\n\n'
      || 'Cancellations and missed sessions: full refund if you cancel in the '
      || 'app up to 24 hours before your session, or if we or your therapist '
      || 'have to cancel. Free rebooking if you reply to your booking email at '
      || 'least 24 hours before. No refund for a session cancelled with less '
      || 'than 24 hours’ notice, or one you don’t join.'
      || E'\n\n'
      || 'Questions about this payment? Just reply to this email.'
      || E'\n\n'
      || '— Δεν είσαι μόνος',
    'therapy-payment/' || new.id || '/' || reference || '/receipt'
  );
  return new;
exception when others then
  raise warning 'receipt email for session % failed: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists therapy_payment_receipt on public.therapy_requests;
create trigger therapy_payment_receipt
  after update on public.therapy_requests
  for each row
  when (new.payment_status = 'paid' and old.payment_status is distinct from 'paid')
  execute function public.notify_therapy_payment_received();

-- ── A paid session cancelled with notice: the care team refunds it ───

-- Cancelled by the client (with the notice the rules above require), by
-- an admin, or by the therapist's side: the care team is asked to refund
-- it in Play Console. Closures by the sweep have their own email (0016),
-- so they are skipped here. A pending request had no cancellation email
-- of its own until now; the client gets one.
create or replace function public.notify_therapy_refund_due()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  client_email text;
  client_name text;
  client_first text;
  when_text text;
  amount text;
begin
  select u.email::text,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), '')
    into client_email, client_name
    from auth.users u where u.id = new.user_id;
  client_first := public.therapy_client_first_name(new.user_id);
  when_text := case when new.scheduled_at is null then 'not yet scheduled'
                    else public.email_session_time(new.scheduled_at) end;
  amount := '$' || (new.price_cents / 100);

  perform public.send_app_email(
    care_team,
    coalesce(client_email, care_team),
    'Refund due — ' || coalesce(client_name, client_email, 'a client'),
    public.email_layout(
      public.email_escape(when_text),
      'A paid session was cancelled',
      public.email_escape(coalesce(client_name, client_email, 'A client'))
        || '’s session (' || public.email_escape(when_text) || ') was cancelled '
        || case when old.status = 'pending' then 'before it was matched'
                else 'with the notice the policy asks for' end
        || '. They had paid ' || amount || ', so please refund it in Play Console '
        || '(Order management) or however it was taken.',
      public.email_box('#F6F6F6', 'Details',
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
        || public.email_row('Session', public.email_escape(when_text))
        || public.email_row('Payment', public.email_escape(coalesce(new.payment_ref, '—')))
        || public.email_row('Request id', public.email_escape(new.id::text))
        || '</table>'),
      'The refund shows up in the dashboard once RevenueCat reports it.'
    ),
    coalesce(client_name, client_email, 'A client') || '’s session (' || when_text
      || ') was cancelled. They had paid ' || amount || ' — please refund it.'
      || E'\n\n'
      || 'Client: ' || coalesce(client_email, '—') || E'\n'
      || 'Payment: ' || coalesce(new.payment_ref, '—') || E'\n'
      || 'Request id: ' || new.id,
    'therapy-session/' || new.id || '/refund-due/care'
  );

  if old.status = 'pending' then
    perform public.send_app_email(
      client_email,
      care_team,
      'Your request is cancelled — refund on its way',
      public.email_layout(
        'Refund of ' || amount,
        'Request cancelled',
        'Hi ' || public.email_escape(coalesce(client_first, 'there'))
          || ', your therapy request has been cancelled before it was '
          || 'matched, so your ' || amount || ' payment will be refunded in '
          || 'full. Refunds usually reach your card within a few days.',
        public.email_box('#F6F6F6', 'Whenever you’re ready',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || 'You can book again from <strong style="font-weight:600;color:#191919;">'
          || 'Talk to a therapist</strong> in the app. If you’re in crisis, please '
          || 'don’t wait — tap Get help now in the app for crisis lines near you.</div>'),
        'Questions? Just reply to this email.'
      ),
      'Hi ' || coalesce(client_first, 'there') || ','
        || E'\n\n'
        || 'Your therapy request has been cancelled before it was matched, so '
        || 'your ' || amount || ' payment will be refunded in full.'
        || E'\n\n'
        || 'You can book again from Talk to a therapist in the app whenever you’re ready.'
        || E'\n\n' || '— Δεν είσαι μόνος',
      'therapy-session/' || new.id || '/refund-due/client'
    );
  end if;
  return new;
exception when others then
  raise warning 'refund-due email for session % failed: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists therapy_refund_due_notify on public.therapy_requests;
create trigger therapy_refund_due_notify
  after update on public.therapy_requests
  for each row
  when (new.status = 'cancelled'
        and old.status in ('pending', 'confirmed')
        and new.payment_status = 'paid'
        and new.close_reason is null)
  execute function public.notify_therapy_refund_due();

-- ── The sweep: expire drafts, tell no-shows ──────────────────────────

-- Same as in 0016, plus: drafts older than a day are cancelled, and a
-- client who never joined is emailed and notified that the session is
-- not refunded.
create or replace function public.close_out_elapsed_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  grace constant interval := interval '2 hours';
  r record;
  closed_row public.therapy_requests%rowtype;
  closed integer := 0;
  new_status text;
  reason text;
  client_email text;
  client_name text;
  client_first text;
  therapist_name text;
  when_text text;
  what text;
  todo text;
begin
  -- Drafts nobody paid for.
  update public.therapy_requests
  set status = 'cancelled',
      cancelled_at = now(),
      close_reason = 'unpaid'
  where status = 'awaiting_payment'
    and created_at < now() - interval '24 hours';

  for r in
    select t.*
    from public.therapy_requests t
    where t.status = 'confirmed'
      and t.scheduled_at is not null
      and t.scheduled_at
          + make_interval(mins => t.duration_minutes) + grace <= now()
    order by t.scheduled_at
    for update skip locked
  loop
    if r.payment_status = 'unpaid' then
      new_status := 'cancelled';
      reason := 'unpaid';
    elsif r.therapist_joined_at is not null then
      new_status := 'completed';
      reason := case when r.client_joined_at is null
                     then 'client_no_show' else 'auto_completed' end;
    else
      new_status := 'cancelled';
      reason := case when r.client_joined_at is null
                     then 'nobody_joined' else 'therapist_no_show' end;
    end if;

    update public.therapy_requests
    set status = new_status,
        close_reason = reason,
        completed_at = case when new_status = 'completed' then now() end,
        cancelled_at = case when new_status = 'cancelled' then now() end
    where id = r.id
    returning * into closed_row;
    closed := closed + 1;

    if reason = 'auto_completed' then
      continue;
    end if;

    begin
      select u.email::text,
             nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                                  u.raw_user_meta_data ->> 'name', '')), '')
        into client_email, client_name
        from auth.users u where u.id = r.user_id;
      client_first := public.therapy_client_first_name(r.user_id);
      select t.full_name into therapist_name
        from public.therapists t where t.id = r.therapist_id;
      when_text := public.email_session_time(r.scheduled_at);

      -- The client who didn't turn up hears it from us, in the app and
      -- by email, with the policy they agreed to when they paid.
      if reason = 'client_no_show' then
        perform public.queue_session_notifications(closed_row, 'session_missed');
        perform public.send_app_email(
          client_email,
          care_team,
          'You missed your session',
          public.email_layout(
            public.email_escape(when_text),
            'You missed your session',
            'Hi ' || public.email_escape(coalesce(client_first, 'there'))
              || ', ' || public.email_escape(coalesce(therapist_name, 'your therapist'))
              || ' was in the call for your session on '
              || public.email_escape(when_text) || ', but you didn’t join. '
              || 'We hope everything is okay.',
            public.email_box('#FFF8E6', 'About your payment',
              '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
              || 'As set out when you booked, a session that isn’t joined or '
              || 'rescheduled at least 24 hours ahead isn’t refunded — your '
              || 'therapist set that time aside for you. The '
              || '$' || (r.price_cents / 100) || ' payment for this session '
              || 'has been used.</div>')
            || '<div style="height:12px;font-size:0;line-height:0;">&nbsp;</div>'
            || public.email_box('#F6F6F6', 'Whenever you’re ready',
              '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
              || 'You can book another session from '
              || '<strong style="font-weight:600;color:#191919;">Talk to a therapist</strong> '
              || 'in the app. If something went wrong on the day — the app '
              || 'wouldn’t connect, or an emergency — reply to this email and '
              || 'tell us. If you’re in crisis, please don’t wait: tap Get '
              || 'help now in the app.</div>'),
            'Questions? Just reply to this email.'
          ),
          'Hi ' || coalesce(client_first, 'there') || ','
            || E'\n\n'
            || coalesce(therapist_name, 'Your therapist') || ' was in the call '
            || 'for your session on ' || when_text || ', but you didn’t join. '
            || 'We hope everything is okay.'
            || E'\n\n'
            || 'As set out when you booked, a session that isn’t joined or '
            || 'rescheduled at least 24 hours ahead isn’t refunded. The $'
            || (r.price_cents / 100) || ' payment for this session has been used.'
            || E'\n\n'
            || 'You can book another session from Talk to a therapist in the '
            || 'app. If something went wrong on the day, reply to this email '
            || 'and tell us.'
            || E'\n\n' || '— Δεν είσαι μόνος',
          'therapy-session/' || r.id || '/missed/client'
        );
      end if;

      what := case reason
        when 'client_no_show' then
          'The therapist joined the call but the client never did. The '
          || 'session counts as delivered: it is marked completed and stays '
          || 'paid — under the policy no refund is due. The client has been '
          || 'emailed and notified.'
        when 'therapist_no_show' then
          'The client joined the call but the therapist never did. The '
          || 'session is cancelled.'
        when 'nobody_joined' then
          'Neither the client nor the therapist joined the call. The session '
          || 'is cancelled.'
        else
          'The client never paid for it. The session is cancelled so they can '
          || 'book again.'
      end;
      todo := case
        when new_status = 'cancelled' and r.payment_status = 'paid' then
          'They had paid $' || (r.price_cents / 100)
          || ', so please arrange the refund.'
        when reason = 'therapist_no_show' then
          'You may want to check in with ' || coalesce(therapist_name, 'the therapist') || '.'
        else 'Nothing to do unless this looks wrong.'
      end;

      perform public.send_app_email(
        care_team,
        coalesce(client_email, care_team),
        'Session closed automatically — '
          || coalesce(client_name, client_email, 'a client'),
        public.email_layout(
          public.email_escape(when_text),
          'Session closed automatically',
          public.email_escape(coalesce(client_name, client_email, 'A client'))
            || '’s session with '
            || public.email_escape(coalesce(therapist_name, 'their therapist'))
            || ' on ' || public.email_escape(when_text)
            || ' ended without anyone finishing it. '
            || public.email_escape(what),
          public.email_box('#F6F6F6', 'Details',
            '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
            || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
            || public.email_row('Therapist', public.email_escape(coalesce(therapist_name, '—')))
            || public.email_row('Session', public.email_escape(when_text))
            || public.email_row('Now', public.email_escape(new_status || ' (' || reason || ')'))
            || public.email_row('Payment', public.email_escape(r.payment_status))
            || public.email_row('Request id', public.email_escape(r.id::text))
            || '</table>'),
          public.email_escape(todo)
        ),
        coalesce(client_name, client_email, 'A client') || '’s session with '
          || coalesce(therapist_name, 'their therapist') || ' on ' || when_text
          || ' ended without anyone finishing it. ' || what
          || E'\n\n' || todo
          || E'\n\n'
          || 'Client: ' || coalesce(client_email, '—') || E'\n'
          || 'Now: ' || new_status || ' (' || reason || ')' || E'\n'
          || 'Payment: ' || r.payment_status || E'\n'
          || 'Request id: ' || r.id,
        'therapy-session/' || r.id || '/auto-closed/care'
      );
    exception when others then
      raise warning 'auto-close email for session % failed: %', r.id, sqlerrm;
    end;
  end loop;
  return closed;
end;
$$;

revoke all on function public.close_out_elapsed_sessions() from public, anon, authenticated;
