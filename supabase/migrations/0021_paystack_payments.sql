-- Paystack for therapy sessions.
--
-- Sessions were paid for as a Google Play one-time product through
-- RevenueCat. From now on the app takes the payment through Paystack
-- instead: card, M-Pesa / mobile money, and Apple Pay where Paystack
-- offers it to the merchant account.
--
--   • The paystack-payment Edge Function opens a Paystack checkout for a
--     draft or unpaid session and records it here (paystack_checkouts),
--     then confirms it by asking Paystack — the app's word is never taken.
--   • The paystack-webhook Edge Function hears charge.success (so a
--     payment lands even if the app closed mid-way) and refund.processed
--     (the session goes back to unpaid, through record_therapy_refunds).
--   • A charge for a session that can no longer be paid for (a draft the
--     client discarded, or one the sweep expired) is never attached to
--     anything: the care team is emailed to refund it.
--   • The receipt, refund and refund-due emails name Paystack instead of
--     Google Play when that is how the session was paid.
--
-- payment_ref for these payments is 'paystack:<reference>'. Older
-- 'revenuecat:' payments keep working as before.
--
-- Builds on 0012 (refunds) and 0019 (receipts, refund due), which must be
-- applied first.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then deploy:
--   supabase functions deploy paystack-payment
--   supabase functions deploy paystack-webhook --no-verify-jwt

-- ── Checkouts ────────────────────────────────────────────────────────

-- One row per Paystack transaction the app opened. Only the Edge
-- Functions (service role) read or write it.
create table if not exists public.paystack_checkouts (
  reference text primary key,
  request_id uuid references public.therapy_requests (id) on delete set null,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount integer not null check (amount > 0),
  currency text not null,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  refund_requested_at timestamptz
);

create index if not exists paystack_checkouts_request_idx
  on public.paystack_checkouts (request_id, created_at desc);

alter table public.paystack_checkouts enable row level security;
revoke all on public.paystack_checkouts from anon, authenticated;

-- A successful charge that couldn't be attached to its session. Emails
-- the care team once per reference; returns false if it already had.
create or replace function public.paystack_payment_needs_refund(
  p_reference text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  c record;
  client_email text;
  amount text;
begin
  update public.paystack_checkouts
    set refund_requested_at = now()
    where reference = p_reference and refund_requested_at is null
    returning * into c;
  if not found then
    return false;
  end if;

  select u.email::text into client_email
    from auth.users u where u.id = c.user_id;
  amount := c.currency || ' ' || to_char(c.amount / 100.0, 'FM999999990.00');

  perform public.send_app_email(
    care_team,
    coalesce(client_email, care_team),
    'Refund needed — Paystack payment with no session',
    public.email_layout(
      'Paystack ' || public.email_escape(c.reference),
      'A payment needs refunding',
      public.email_escape(coalesce(client_email, 'A client'))
        || ' paid ' || amount || ' for a session request that had already '
        || 'been cancelled, so it wasn’t attached to anything. Please refund '
        || 'it in the Paystack dashboard (Transactions → this reference → Refund).',
      public.email_box('#F6F6F6', 'Details',
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
        || public.email_row('Amount', amount)
        || public.email_row('Reference', public.email_escape(c.reference))
        || public.email_row('Request id', public.email_escape(coalesce(c.request_id::text, '—')))
        || '</table>'),
      'Sent by the paystack-payment / paystack-webhook functions.'
    ),
    coalesce(client_email, 'A client') || ' paid ' || amount
      || ' for a session request that had already been cancelled. Please '
      || 'refund it in the Paystack dashboard.' || E'\n\n'
      || 'Reference: ' || c.reference || E'\n'
      || 'Request id: ' || coalesce(c.request_id::text, '—'),
    'paystack-orphan/' || c.reference
  );
  return true;
end;
$$;

revoke all on function public.paystack_payment_needs_refund(text) from public, anon, authenticated;
grant execute on function public.paystack_payment_needs_refund(text) to service_role;

-- ── Refunds (as in 0012, naming where the money went back from) ──────

create or replace function public.record_therapy_refunds(
  p_user_id uuid,
  p_refs text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  r record;
  changed integer := 0;
  client_email text;
  client_name text;
  client_first text;
  when_text text;
  ahead boolean;
begin
  if p_user_id is null or coalesce(cardinality(p_refs), 0) = 0 then
    return 0;
  end if;

  select u.email::text,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), '')
    into client_email, client_name
    from auth.users u where u.id = p_user_id;
  client_first := public.therapy_client_first_name(p_user_id);

  for r in
    update public.therapy_requests
    set payment_status = 'unpaid',
        refunded_at = now(),
        refunded_payment_ref = payment_ref,
        payment_ref = null,
        paid_at = null
    where user_id = p_user_id
      and payment_status = 'paid'
      and payment_ref = any (p_refs)
    returning id, status, scheduled_at, price_cents, therapist_id,
              refunded_payment_ref
  loop
    changed := changed + 1;
    ahead := r.status in ('pending', 'confirmed');
    when_text := case when r.scheduled_at is null then 'not yet scheduled'
                      else public.email_session_time(r.scheduled_at) end;

    perform public.send_app_email(
      care_team,
      coalesce(client_email, care_team),
      'Refund — ' || coalesce(client_name, client_email, 'a client'),
      public.email_layout(
        case when r.refunded_payment_ref like 'paystack:%' then 'Paystack refund' else 'Google Play refund' end,
        'A session payment was refunded',
        public.email_escape(coalesce(client_name, client_email, 'A client'))
          || ' was refunded $' || (r.price_cents / 100)
          || ' for their session ' || public.email_escape(when_text) || '. '
          || case when ahead
             then 'The session is now unpaid: they can’t join until they pay again, and the app asks them to.'
             else 'The session had already ' || r.status || ', so the money is gone but the session isn’t.' end,
        public.email_box('#F6F6F6', 'Details',
          '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
          || public.email_row('Session', public.email_escape(when_text))
          || public.email_row('Status', public.email_escape(r.status))
          || public.email_row('Purchase', public.email_escape(r.refunded_payment_ref))
          || public.email_row('Request id', public.email_escape(r.id::text))
          || '</table>'),
        'Open the care team dashboard in the app to cancel the session, '
          || 'waive the fee, or leave it for them to pay again.'
      ),
      coalesce(client_name, client_email, 'A client')
        || ' was refunded $' || (r.price_cents / 100)
        || ' for their session ' || when_text || ' (status ' || r.status || ').'
        || E'\n\n'
        || case when ahead
           then 'The session is now unpaid: they can’t join until they pay again.'
           else 'The session had already ' || r.status || '.' end
        || E'\n\n'
        || 'Client: ' || coalesce(client_email, '—') || E'\n'
        || 'Purchase: ' || r.refunded_payment_ref || E'\n'
        || 'Request id: ' || r.id,
      'therapy-refund/' || r.id || '/' || r.refunded_payment_ref || '/care'
    );

    if ahead then
      perform public.send_app_email(
        client_email,
        care_team,
        'Your refund went through — your session is now unpaid',
        public.email_layout(
          public.email_escape(when_text),
          'Your payment was refunded',
          'Hi ' || public.email_escape(coalesce(client_first, 'there'))
            || ', ' || case when r.refunded_payment_ref like 'paystack:%' then 'we have' else 'Google Play has' end || ' refunded your $' || (r.price_cents / 100)
            || ' payment, so your session ' || public.email_escape(when_text)
            || ' is no longer paid for. If you still want it, pay again in the '
            || 'app and the Join button unlocks. If you meant to cancel, just '
            || 'reply and we’ll take care of it.',
          public.email_box('#F6F6F6', 'Changed your mind?',
            '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
            || 'That’s completely fine. You can book again from '
            || '<strong style="font-weight:600;color:#191919;">Talk to a therapist</strong> '
            || 'in the app whenever you’re ready.</div>'),
          'Questions? Just reply to this email.'
        ),
        'Hi ' || coalesce(client_first, 'there') || ','
          || E'\n\n'
          || case when r.refunded_payment_ref like 'paystack:%' then 'We have' else 'Google Play has' end || ' refunded your $' || (r.price_cents / 100)
          || ' payment, so your session ' || when_text
          || ' is no longer paid for. If you still want it, pay again in the '
          || 'app and the Join button unlocks. If you meant to cancel, just '
          || 'reply and we’ll take care of it.'
          || E'\n\n' || '— Δεν είσαι μόνος',
        'therapy-refund/' || r.id || '/' || r.refunded_payment_ref || '/client'
      );
    end if;
  end loop;

  return changed;
end;
$$;

revoke all on function public.record_therapy_refunds(uuid, text[]) from public;
grant execute on function public.record_therapy_refunds(uuid, text[]) to service_role;

-- ── Receipt (as in 0019, naming Paystack) ────────────────────────────

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
    when new.payment_ref like 'paystack:%' then 'Paystack'
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
        || case when new.payment_ref like 'revenuecat:%' then 'Google Play also emails its own order confirmation. ' else '' end
        || 'Questions '
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

-- ── Refund due (as in 0019, pointing at the right dashboard) ─────────

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
        || '. They had paid ' || amount || ', so please refund it in '
        || case when new.payment_ref like 'paystack:%' then 'the Paystack dashboard (Transactions) ' else 'Play Console ' end
        || case when new.payment_ref like 'paystack:%' then '' else '(Order management) ' end
        || 'or however it was taken.',
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
