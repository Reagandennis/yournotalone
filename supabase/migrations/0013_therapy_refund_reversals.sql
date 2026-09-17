-- Refund reversals reach the database too.
--
-- 0012 puts a refunded session back to unpaid. Google occasionally reverses
-- a refund (when it wins a dispute over one). RevenueCat then sends a
-- REFUND_REVERSED event and its record of the purchase is no longer
-- "refunded". The revenuecat-webhook now passes every purchase that isn't
-- refunded to this function; any session that was recorded as refunded with
-- one of them, and hasn't been paid another way since, is paid again with
-- the same purchase, and the care team is emailed.
--
-- If the client had already re-attached the purchase to a newer session
-- with "Already paid?", that newer session keeps it and nothing changes.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then redeploy:
--   supabase functions deploy revenuecat-webhook --no-verify-jwt

create or replace function public.record_therapy_refund_reversals(
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
  when_text text;
begin
  if p_user_id is null or coalesce(cardinality(p_refs), 0) = 0 then
    return 0;
  end if;

  select u.email::text,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), '')
    into client_email, client_name
    from auth.users u where u.id = p_user_id;

  for r in
    update public.therapy_requests t
    set payment_status = 'paid',
        payment_ref = t.refunded_payment_ref,
        paid_at = now(),
        refunded_at = null,
        refunded_payment_ref = null
    where t.user_id = p_user_id
      and t.payment_status = 'unpaid'
      and t.refunded_payment_ref = any (p_refs)
      and not exists (
        select 1 from public.therapy_requests o
        where o.payment_ref = t.refunded_payment_ref
      )
    returning t.id, t.status, t.scheduled_at, t.price_cents, t.payment_ref
  loop
    changed := changed + 1;
    when_text := case when r.scheduled_at is null then 'not yet scheduled'
                      else public.email_session_time(r.scheduled_at) end;

    perform public.send_app_email(
      care_team,
      coalesce(client_email, care_team),
      'Refund reversed — ' || coalesce(client_name, client_email, 'a client'),
      public.email_layout(
        'Google Play refund reversed',
        'A refund was reversed',
        'Google reversed the refund for '
          || public.email_escape(coalesce(client_name, client_email, 'a client'))
          || '’s $' || (r.price_cents / 100) || ' session '
          || public.email_escape(when_text)
          || ', so the money is back with us and the session is paid again. '
          || case when r.status in ('pending', 'confirmed')
             then 'They can join it as before.'
             else 'The session is ' || r.status || ', so nothing else changes.' end,
        public.email_box('#F6F6F6', 'Details',
          '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
          || public.email_row('Session', public.email_escape(when_text))
          || public.email_row('Status', public.email_escape(r.status))
          || public.email_row('Purchase', public.email_escape(r.payment_ref))
          || public.email_row('Request id', public.email_escape(r.id::text))
          || '</table>'),
        'Nothing to do unless you had already waived or cancelled it.'
      ),
      'Google reversed the refund for '
        || coalesce(client_name, client_email, 'a client')
        || '’s $' || (r.price_cents / 100) || ' session ' || when_text
        || ' (status ' || r.status || '). The session is paid again.'
        || E'\n\n'
        || 'Client: ' || coalesce(client_email, '—') || E'\n'
        || 'Purchase: ' || r.payment_ref || E'\n'
        || 'Request id: ' || r.id,
      'therapy-refund-reversed/' || r.id || '/' || r.payment_ref || '/care'
    );
  end loop;

  return changed;
end;
$$;

revoke all on function public.record_therapy_refund_reversals(uuid, text[]) from public;
grant execute on function public.record_therapy_refund_reversals(uuid, text[]) to service_role;
