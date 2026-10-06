-- Paystack charges in Kenyan shillings.
--
-- Prices are still shown in USD ($20 a session), but the Paystack account
-- settles in KES, so paystack-payment charges Ksh 2,600 per session. The
-- receipt and the refund-due email now name the amount actually charged,
-- e.g. "Ksh 2,600 (US$20.00)", read from paystack_checkouts. Payments made
-- any other way read as before.
--
-- Builds on 0021. Run in Supabase dashboard → SQL Editor (safe to re-run).

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
  -- Paid through Paystack: name what was actually charged (0022).
  if new.payment_ref like 'paystack:%' then
    amount := coalesce((
      select case c.currency when 'KES' then 'Ksh ' else c.currency || ' ' end
             || to_char(c.amount / 100.0, 'FM999,999,990') || ' (' || amount || ')'
        from public.paystack_checkouts c
       where c.reference = substr(new.payment_ref, 10)), amount);
  end if;
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
  -- Paid through Paystack: name what was actually charged (0022).
  if new.payment_ref like 'paystack:%' then
    amount := coalesce((
      select case c.currency when 'KES' then 'Ksh ' else c.currency || ' ' end
             || to_char(c.amount / 100.0, 'FM999,999,990') || ' (' || amount || ')'
        from public.paystack_checkouts c
       where c.reference = substr(new.payment_ref, 10)), amount);
  end if;

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
