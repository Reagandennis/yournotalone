-- Refunds reach the database.
--
-- Until now nothing listened for refunds. confirm-session-payment marks a
-- session paid from RevenueCat's record, but a client could then refund
-- themselves in Google Play (allowed within 48 hours) and the session stayed
-- "paid" and joinable, and nobody was told.
--
-- Now the revenuecat-webhook Edge Function receives RevenueCat's events and,
-- on any event about a customer, re-reads their purchases from RevenueCat
-- API v2 and calls record_therapy_refunds with the refunded purchase ids.
-- For each session that was paid with one of them:
--   • payment goes back to unpaid, so the Join button locks again and the
--     app asks them to pay (the same path as before they paid);
--   • the refund is kept on the row (refunded_at, refunded_payment_ref) so
--     the dashboard shows it and the purchase can't be attached again;
--   • the care team is emailed, and so is the client if the session is
--     still ahead of them.
--
-- A refund that Google later reverses is not undone here: RevenueCat's
-- record no longer says refunded, the purchase id is free again, and the
-- client's "Already paid?" button re-attaches it.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then:
--   supabase functions deploy revenuecat-webhook --no-verify-jwt
-- and see the function's header for the RevenueCat dashboard setup.

alter table public.therapy_requests
  add column if not exists refunded_at timestamptz,
  add column if not exists refunded_payment_ref text;

-- Called by the webhook with the service role. p_refs are payment_ref
-- values ('revenuecat:<purchase id>'); only sessions of p_user_id are
-- touched so a mistaken id can't reach anyone else's rows. Returns how many
-- sessions were changed.
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
        'Google Play refund',
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
            || ', Google Play has refunded your $' || (r.price_cents / 100)
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
          || 'Google Play has refunded your $' || (r.price_cents / 100)
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

-- Same as in 0009, plus refunded_at so the dashboard can show it. The
-- return type changes, so the function is dropped first.
drop function if exists public.admin_list_therapy_requests();
create function public.admin_list_therapy_requests()
returns table (
  id uuid,
  created_at timestamptz,
  status text,
  topic text,
  availability text[],
  note text,
  is_free_session boolean,
  scheduled_at timestamptz,
  duration_minutes smallint,
  price_cents integer,
  currency text,
  payment_status text,
  paid_at timestamptz,
  refunded_at timestamptz,
  therapist_id uuid,
  therapist_name text,
  client_id uuid,
  client_name text,
  client_email text,
  client_summary text,
  completed_at timestamptz,
  client_rating smallint,
  client_comment text,
  therapist_rating smallint,
  therapist_comment text,
  therapist_flags text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return query
  select r.id, r.created_at, r.status, r.topic, r.availability, r.note,
         r.is_free_session, r.scheduled_at, r.duration_minutes,
         r.price_cents, r.currency, r.payment_status, r.paid_at,
         r.refunded_at,
         r.therapist_id, t.full_name,
         r.user_id,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), ''),
         u.email::text,
         r.client_summary, r.completed_at,
         cr.rating, cr.comment, tr.rating, tr.comment, tr.flags
  from public.therapy_requests r
  left join auth.users u on u.id = r.user_id
  left join public.therapists t on t.id = r.therapist_id
  left join public.therapy_ratings cr
    on cr.request_id = r.id and cr.author_role = 'client'
  left join public.therapy_ratings tr
    on tr.request_id = r.id and tr.author_role = 'therapist'
  order by r.created_at desc
  limit 500;
end;
$$;

grant execute on function public.admin_list_therapy_requests() to authenticated;
