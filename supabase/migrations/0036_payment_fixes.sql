-- 0036: payment fixes from the 26 November 2026 review.
--
--  1. Recording a refund (and a reversed one) is for the server only. Both
--     functions were revoked from PUBLIC, but Supabase grants EXECUTE to
--     anon and authenticated directly, so any signed-in client could mark
--     its own paid session refunded — or a refunded one paid again. They
--     are now revoked from those roles and also refuse, inside, anyone
--     calling with a client's role. The edge functions (service role) and
--     the SQL editor / cron (no client role) still can.
--  2. A Paystack refund marks its checkout refunded (paystack_checkouts
--     .refunded_at), so the same transaction can never pay for a session
--     again. The card's country is kept on the checkout too (card_country).
--     Only RevenueCat refunds can be reversed; a Paystack refund can't.
--  3. Pricing by country can't be talked down. The country is fixed by any
--     session ever paid, refunded or waived, not only one paid right now;
--     once a country is on file, detection may only move it to a country
--     whose session costs the same or more (the care team can move it
--     anywhere); and paystack_record_card_country() keeps the card's
--     country and emails the care team when it's a dearer country than
--     the one the client was priced in.
--  4. Rescheduling a session, or giving it to another therapist, clears
--     who joined and any close reason, so a join for the old time can't
--     complete (or no-show) the new one.
--  5. A therapist can only complete a session that's paid for (or free, or
--     waived) and that they joined. The care team still can either way.
--  6. A therapist's fee is only written, and only counted as owed, for a
--     session whose payment stands (paid, waived or nothing to pay), and —
--     unless the care team completed it — that the therapist joined. A
--     refund on a completed session that hasn't been paid out takes the
--     fee off it; a reversed RevenueCat refund puts it back.
--  7. A payout marks the sessions it covers and adds them up in the same
--     statement, so a session completed or refunded meanwhile can't end
--     up paid for but not in the total (or the other way round).
--  8. The care team changing a payment keeps its history: a payment marked
--     waived keeps its purchase (so a RevenueCat purchase still counts as
--     used), one marked unpaid moves it to refunded_payment_ref; and only
--     a session that hasn't happened can be changed.
--  9. Deleting an account less than 24 hours before a paid session no
--     longer tells the care team it was cancelled "with the notice the
--     policy asks for": they're told it was late and theirs to decide.
--     (The client's "we'll arrange your refund" is in
--     notify_therapy_session_change, which 0037 redefines; it reads the
--     same app.therapy_account_deletion setting set here.)
--
-- Run after 0035. Safe to run more than once. Then deploy the edge
-- functions that read paystack_checkouts.refunded_at and call
-- paystack_record_card_country (paystack-payment, paystack-webhook).

begin;

-- ── 1. Server-only payment functions ─────────────────────────────────

-- Raises unless the caller is the server: the service role, or a direct
-- database session (SQL editor, cron) that isn't acting as a client.
-- Inside a SECURITY DEFINER function current_user is the owner, so the
-- caller's role is read from the session's role setting (PostgREST sets
-- it to anon / authenticated / service_role) and from the request's JWT.
create or replace function public.payments_require_server()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if coalesce(current_setting('role', true), 'none') in ('anon', 'authenticated')
     or coalesce(auth.role(), '') in ('anon', 'authenticated') then
    raise exception 'Only the server can do this.' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.payments_require_server() from public, anon, authenticated;
grant execute on function public.payments_require_server() to service_role;

-- ── 2. Paystack checkouts: refunded, and the card's country ──────────

alter table public.paystack_checkouts
  add column if not exists refunded_at timestamptz,
  add column if not exists card_country text check (card_country ~ '^[A-Z]{2}$');

-- Paystack refunds recorded before this migration.
update public.paystack_checkouts c
   set refunded_at = r.refunded_at
  from public.therapy_requests r
 where r.refunded_payment_ref = 'paystack:' || c.reference
   and r.refunded_at is not null
   and c.refunded_at is null;

-- ── 1–2, 6. Recording refunds and reversals ──────────────────────────

-- As in 0031, for the server only; a Paystack refund also marks its
-- checkout refunded, and a completed session that hasn't been paid out
-- loses its therapist fee.
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
  perform public.payments_require_server();
  if p_user_id is null or coalesce(cardinality(p_refs), 0) = 0 then
    return 0;
  end if;

  -- A refunded Paystack transaction never pays for anything again,
  -- whether or not a session still holds it.
  update public.paystack_checkouts c
     set refunded_at = coalesce(c.refunded_at, now())
   where 'paystack:' || c.reference = any (p_refs)
     and c.user_id = p_user_id;

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
        paid_at = null,
        -- A completed session that hasn't been paid out no longer earns.
        therapist_fee_minor = case when status = 'completed' and payout_id is null
                                   then null else therapist_fee_minor end,
        therapist_fee_currency = case when status = 'completed' and payout_id is null
                                      then null else therapist_fee_currency end
    where user_id = p_user_id
      and payment_status = 'paid'
      and payment_ref = any (p_refs)
    returning id, status, scheduled_at, price_cents, currency, therapist_id,
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
          || ' was refunded ' || public.therapy_price_label(r.price_cents, r.currency)
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
        || ' was refunded ' || public.therapy_price_label(r.price_cents, r.currency)
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
            || ', ' || case when r.refunded_payment_ref like 'paystack:%' then 'we have' else 'Google Play has' end || ' refunded your ' || public.therapy_price_label(r.price_cents, r.currency)
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
          || case when r.refunded_payment_ref like 'paystack:%' then 'We have' else 'Google Play has' end || ' refunded your ' || public.therapy_price_label(r.price_cents, r.currency)
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


-- As in 0031, for the server only, for RevenueCat purchases only (a
-- Paystack refund is final), and putting back the therapist's fee on a
-- completed session.
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
  perform public.payments_require_server();
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
        refunded_payment_ref = null,
        -- A completed session earns again, as it did before the refund.
        therapist_fee_minor = case
          when t.status = 'completed' and t.payout_id is null and t.therapist_fee_minor is null
               and t.therapist_id is not null
          then (select f.fee_minor from public.therapy_session_fee(t) f)
          else t.therapist_fee_minor end,
        therapist_fee_currency = case
          when t.status = 'completed' and t.payout_id is null and t.therapist_fee_minor is null
               and t.therapist_id is not null
          then (select f.currency from public.therapy_session_fee(t) f)
          else t.therapist_fee_currency end
    where t.user_id = p_user_id
      and t.payment_status = 'unpaid'
      -- Only Google Play (RevenueCat) refunds are ever reversed.
      and t.refunded_payment_ref like 'revenuecat:%'
      and t.refunded_payment_ref = any (p_refs)
      and not exists (
        select 1 from public.therapy_requests o
        where o.payment_ref = t.refunded_payment_ref
      )
    returning t.id, t.status, t.scheduled_at, t.price_cents, t.currency, t.payment_ref
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
          || '’s ' || public.therapy_price_label(r.price_cents, r.currency) || ' session '
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
        || '’s ' || public.therapy_price_label(r.price_cents, r.currency) || ' session ' || when_text
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

revoke execute on function public.record_therapy_refunds(uuid, text[]) from public, anon, authenticated;
grant execute on function public.record_therapy_refunds(uuid, text[]) to service_role;
revoke execute on function public.record_therapy_refund_reversals(uuid, text[]) from public, anon, authenticated;
grant execute on function public.record_therapy_refund_reversals(uuid, text[]) to service_role;

-- Trigger functions can't be called directly and run whatever their grants
-- say, but nothing outside the database should hold EXECUTE on them.
revoke execute on function public.notify_therapy_request() from public, anon, authenticated;
revoke execute on function public.notify_therapy_payment_received() from public, anon, authenticated;
revoke execute on function public.notify_therapy_refund_due() from public, anon, authenticated;
revoke execute on function public.therapy_requests_flag_refunded_checkout() from public, anon, authenticated;

-- ── 3. The pricing country can't be talked down ──────────────────────

-- As in 0031, counting every session that was ever paid for — including
-- one refunded since (its purchase is kept in refunded_payment_ref) and
-- one the care team waived — not only one that's paid right now. Without
-- this a refund, or a waiver, reopened the country for a cheaper one.
create or replace function public.therapy_country_locked(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.therapy_requests r
    where r.user_id = p_user
      and (r.payment_status in ('paid', 'waived')
           or r.refunded_payment_ref is not null
           or r.refunded_at is not null)
  );
$$;

revoke execute on function public.therapy_country_locked(uuid) from public, anon, authenticated;

-- Whether moving a client from one country to another, without the care
-- team, is allowed: only to a country whose session costs at least as
-- much (Paystack's charge, in the same currency). Anything else would let
-- a phone's reported country pick a cheaper price.
create or replace function public.therapy_country_move_ok(p_from text, p_to text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p_old public.therapy_prices;
  p_new public.therapy_prices;
begin
  if p_from is null or p_from = p_to then
    return true;
  end if;
  p_old := public.therapy_price_for(p_from);
  p_new := public.therapy_price_for(p_to);
  return p_new.charge_currency = p_old.charge_currency
     and p_new.charge_minor >= p_old.charge_minor;
end;
$$;

revoke execute on function public.therapy_country_move_ok(text, text) from public, anon, authenticated;

-- As in 0035, except that a country already on file only moves to one
-- whose session costs the same or more. What the phone reported is still
-- kept for the care team either way.
create or replace function public.therapy_detect_country(
  p_store text default null,
  p_sim text default null,
  p_region text default null,
  p_platform text default null,
  p_zone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store text := public.country_code_of(p_store);
  v_sim text := public.country_code_of(p_sim);
  v_zone text := public.country_code_of(p_zone);
  v_region text := public.country_code_of(p_region);
  v_pick text := coalesce(v_sim, v_zone, v_store, v_region);
  v_source text := case
    when v_sim is not null then 'sim'
    when v_zone is not null then 'zone'
    when v_store is not null then 'store'
    when v_region is not null then 'region'
  end;
  v_platform text := nullif(left(lower(trim(coalesce(p_platform, ''))), 20), '');
  cur public.therapy_client_countries%rowtype;
  v_move boolean;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;

  insert into public.therapy_client_countries (
    user_id, country_code, set_by, source, store_country, sim_country,
    zone_country, region_country, platform, detected_at)
  select auth.uid(), v_pick, 'detected', v_source, v_store, v_sim,
         v_zone, v_region, v_platform, now()
  where v_pick is not null
  on conflict (user_id) do nothing;
  if found then
    return public.therapy_price_quote();
  end if;

  select * into cur from public.therapy_client_countries c where c.user_id = auth.uid() for update;
  if not found then
    -- Nothing recognised and nothing on file: the price for everywhere else.
    return public.therapy_price_quote();
  end if;

  v_move := v_pick is not null
            and cur.source is distinct from 'admin'
            and not public.therapy_country_locked(auth.uid())
            and public.therapy_country_move_ok(cur.country_code, v_pick);
  update public.therapy_client_countries c
     set store_country = v_store, sim_country = v_sim, zone_country = v_zone,
         region_country = v_region,
         platform = coalesce(v_platform, c.platform), detected_at = now(),
         country_code = case when v_move then v_pick else c.country_code end,
         source = case when v_move then v_source else c.source end,
         set_by = case when v_move then 'detected' else c.set_by end,
         updated_at = case when v_move and v_pick is distinct from c.country_code then now() else c.updated_at end
   where c.user_id = auth.uid();
  return public.therapy_price_quote();
end;
$$;

revoke execute on function public.therapy_detect_country(text, text, text, text, text) from public, anon;
grant execute on function public.therapy_detect_country(text, text, text, text, text) to authenticated;

-- As in 0035, with the same rule for older builds' country list: a
-- country already chosen can't be swapped for a cheaper one.
create or replace function public.therapy_set_country(p_country text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_country);
  v_current text;
  v_source text;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if v_code is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  select c.country_code, c.source into v_current, v_source
    from public.therapy_client_countries c where c.user_id = auth.uid()
    for update;
  if v_current is distinct from v_code then
    if public.therapy_country_locked(auth.uid()) then
      raise exception 'Your country is set from your first session. Reply to any of our emails if it has changed.'
        using errcode = 'P0001';
    end if;
    if coalesce(v_source, 'client') <> 'client' then
      raise exception 'Your country comes from where your phone is. If it’s wrong, reply to any of our emails.'
        using errcode = 'P0001';
    end if;
    if not public.therapy_country_move_ok(v_current, v_code) then
      raise exception 'Your country can’t be changed here any more. If it has changed, reply to any of our emails.'
        using errcode = 'P0001';
    end if;
  end if;
  insert into public.therapy_client_countries (user_id, country_code, set_by, source)
  values (auth.uid(), v_code, 'client', 'client')
  on conflict (user_id) do update
  set country_code = excluded.country_code, set_by = 'client', source = 'client', updated_at = now();
  return public.therapy_price_quote();
end;
$$;

revoke execute on function public.therapy_set_country(text) from public, anon;
grant execute on function public.therapy_set_country(text) to authenticated;

-- The country of the card a Paystack checkout was paid with (Paystack's
-- authorization.country_code), called by the edge functions after a
-- successful verify. When it isn't the country the session was priced in
-- and a session there costs more, the care team is emailed once, to follow
-- up: nothing changes on its own, since people do pay with a card from
-- elsewhere. Mobile money has no card country; nothing is sent for it.
create or replace function public.paystack_record_card_country(
  p_reference text,
  p_card_country text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_card_country);
  c public.paystack_checkouts%rowtype;
  r public.therapy_requests%rowtype;
  p_card public.therapy_prices;
  v_priced text;
  v_charged_minor integer;
  v_charged_currency text;
  client_email text;
  client_name text;
  priced_name text;
  card_name text;
  when_text text;
begin
  perform public.payments_require_server();
  if v_code is null or nullif(trim(coalesce(p_reference, '')), '') is null then
    return;
  end if;

  select * into c from public.paystack_checkouts
   where reference = p_reference for update;
  if not found then
    return;
  end if;
  update public.paystack_checkouts set card_country = v_code
   where reference = p_reference;
  -- Only the first time a card country is recorded can it raise a flag,
  -- so the care team hears once per checkout.
  if c.card_country is not null then
    return;
  end if;

  select * into r from public.therapy_requests where id = c.request_id;
  if not found then
    return;
  end if;
  v_priced := coalesce(r.pricing_country, '*');
  if v_priced = v_code then
    return;
  end if;
  v_charged_minor := coalesce(r.charge_minor, c.amount);
  v_charged_currency := coalesce(r.charge_currency, c.currency);
  p_card := public.therapy_price_for(v_code);
  if p_card.charge_currency is distinct from v_charged_currency
     or p_card.charge_minor <= v_charged_minor then
    return;
  end if;

  select u.email::text,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), '')
    into client_email, client_name
    from auth.users u where u.id = coalesce(c.user_id, r.user_id);
  select n.name into priced_name from public.countries n where n.code = r.pricing_country;
  priced_name := coalesce(priced_name, r.pricing_country, 'everywhere else (no country on file)');
  select n.name into card_name from public.countries n where n.code = v_code;
  card_name := coalesce(card_name, v_code);
  when_text := case when r.scheduled_at is null then 'not yet scheduled'
                    else public.email_session_time(r.scheduled_at) end;

  perform public.send_app_email(
    public.care_team_email(),
    coalesce(client_email, public.care_team_email()),
    'Card from another country — ' || coalesce(client_name, client_email, 'a client'),
    public.email_layout(
      public.email_escape(card_name || ' card, priced for ' || priced_name),
      'Paid with a card from a dearer country',
      public.email_escape(coalesce(client_name, client_email, 'A client'))
        || ' paid ' || public.email_escape(public.therapy_price_label(v_charged_minor, v_charged_currency))
        || ', the price for ' || public.email_escape(priced_name)
        || ', with a card from ' || public.email_escape(card_name)
        || ', where a session is '
        || public.email_escape(public.therapy_price_label(p_card.charge_minor, p_card.charge_currency))
        || '. Nothing has changed: the session is paid and stays booked.',
      public.email_box('#F6F6F6', 'Details',
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Client', public.email_escape(coalesce(client_email, '—')))
        || public.email_row('Priced for', public.email_escape(priced_name))
        || public.email_row('Card from', public.email_escape(card_name))
        || public.email_row('Charged', public.email_escape(public.therapy_price_label(v_charged_minor, v_charged_currency)))
        || public.email_row('Price there', public.email_escape(public.therapy_price_label(p_card.charge_minor, p_card.charge_currency)))
        || public.email_row('Session', public.email_escape(when_text))
        || public.email_row('Paystack', public.email_escape(c.reference))
        || public.email_row('Request id', public.email_escape(r.id::text))
        || '</table>'),
      'People do pay with a card from somewhere else. If they live in '
        || public.email_escape(card_name) || ', set their country from the care '
        || 'team dashboard: it applies from their next session.'
    ),
    coalesce(client_name, client_email, 'A client') || ' paid '
      || public.therapy_price_label(v_charged_minor, v_charged_currency)
      || ', the price for ' || priced_name || ', with a card from ' || card_name
      || ', where a session is ' || public.therapy_price_label(p_card.charge_minor, p_card.charge_currency)
      || '. Nothing has changed: the session is paid and stays booked.'
      || E'\n\n'
      || 'If they live in ' || card_name || ', set their country from the care team '
      || 'dashboard: it applies from their next session.'
      || E'\n\n'
      || 'Client: ' || coalesce(client_email, '—') || E'\n'
      || 'Session: ' || when_text || E'\n'
      || 'Paystack: ' || c.reference || E'\n'
      || 'Request id: ' || r.id,
    'paystack-country/' || c.reference
  );
end;
$$;

revoke execute on function public.paystack_record_card_country(text, text) from public, anon, authenticated;
grant execute on function public.paystack_record_card_country(text, text) to service_role;

-- ── 4. A new time or therapist starts the joins afresh ───────────────

-- As in 0019, plus: when a session still to happen is moved to another
-- time or given to another therapist, who joined (and any close reason)
-- goes, since those were for the old booking. Otherwise a therapist who
-- opened the call for the old time counted as joined for the new one —
-- enough for the sweep to complete it, and earn, without a session.
create or replace function public.therapy_requests_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.scheduled_at is distinct from old.scheduled_at then
    new.reminder_sent_at := null;
  end if;
  if (new.scheduled_at is distinct from old.scheduled_at
      or new.therapist_id is distinct from old.therapist_id)
     and old.status not in ('completed', 'cancelled')
     and new.status not in ('completed', 'cancelled') then
    new.client_joined_at := null;
    new.therapist_joined_at := null;
    new.close_reason := null;
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

-- ── 5. Completing a session ──────────────────────────────────────────

-- As in 0016, plus: a therapist can only complete a session that's paid
-- for (or free, or waived) and that they joined. The care team can still
-- complete any confirmed session that has started, e.g. one held another
-- way after the call failed.
create or replace function public.complete_therapy_session(
  p_request_id uuid,
  p_summary text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  req public.therapy_requests%rowtype;
begin
  select * into req from public.therapy_requests
    where id = p_request_id for update;
  if not found
     or (req.therapist_id is distinct from public.current_therapist_id()
         and not public.is_admin()) then
    raise exception 'That session isn’t one of yours.' using errcode = 'P0002';
  end if;
  if req.status = 'completed' then
    update public.therapy_requests
    set client_summary = nullif(trim(p_summary), '')
    where id = p_request_id;
    return;
  end if;
  if req.status = 'cancelled' and req.close_reason is not null then
    raise exception 'This session was closed automatically because %. If it did go ahead, tell the care team and they’ll sort it out.',
      case req.close_reason
        when 'unpaid' then 'the client never paid'
        when 'therapist_no_show' then 'you didn’t join the call'
        else 'nobody joined the call'
      end
      using errcode = '22023';
  end if;
  if req.status <> 'confirmed' then
    raise exception 'Only a confirmed session can be completed.' using errcode = '22023';
  end if;
  if req.scheduled_at > now() then
    raise exception 'This session hasn’t started yet.' using errcode = '22023';
  end if;
  if not public.is_admin() then
    if req.payment_status not in ('paid', 'waived', 'not_required') then
      raise exception 'This session hasn’t been paid for, so it can’t be completed. If it went ahead, tell the care team and they’ll sort it out.'
        using errcode = '22023';
    end if;
    if req.therapist_joined_at is null then
      raise exception 'You didn’t join the call for this session, so it can’t be completed. If it went ahead another way, tell the care team and they’ll sort it out.'
        using errcode = '22023';
    end if;
  end if;
  update public.therapy_requests
  set status = 'completed',
      completed_at = now(),
      client_summary = nullif(trim(p_summary), '')
  where id = p_request_id;
end;
$$;

revoke execute on function public.complete_therapy_session(uuid, text) from public, anon;
grant execute on function public.complete_therapy_session(uuid, text) to authenticated;

-- ── 6. Fees only for sessions that were paid for and held ────────────

-- As in 0034, writing the fee only when the session's payment stands
-- (paid, waived, or nothing to pay) and, unless the care team completed
-- it, the therapist joined the call.
create or replace function public.therapy_requests_therapist_fee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  f record;
begin
  if new.status = 'completed' and old.status is distinct from 'completed'
     and new.therapist_id is not null and new.therapist_fee_minor is null
     and new.payment_status in ('paid', 'waived', 'not_required')
     and (new.therapist_joined_at is not null or public.is_admin()) then
    select * into f from public.therapy_session_fee(new);
    new.therapist_fee_minor := f.fee_minor;
    new.therapist_fee_currency := f.currency;
  end if;
  return new;
end;
$$;

revoke execute on function public.therapy_requests_therapist_fee() from public, anon, authenticated;

-- As in 0034, for sessions whose payment stands only, so a refunded one
-- isn't given its fee back.
create or replace function public.therapist_fill_missing_fees()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.therapy_requests r
     set therapist_fee_minor = f.fee_minor,
         therapist_fee_currency = f.currency
    from public.therapy_requests s
    cross join lateral public.therapy_session_fee(s) f
   where s.id = r.id
     and r.status = 'completed'
     and r.therapist_id is not null
     and r.therapist_fee_minor is null
     and r.payout_id is null
     and r.payment_status in ('paid', 'waived', 'not_required');
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke execute on function public.therapist_fill_missing_fees() from public, anon, authenticated;

-- Fees already written on completed sessions whose payment has since been
-- refunded or taken back, and that haven't been paid out.
update public.therapy_requests
   set therapist_fee_minor = null,
       therapist_fee_currency = null
 where status = 'completed'
   and payout_id is null
   and therapist_fee_minor is not null
   and payment_status not in ('paid', 'waived', 'not_required');

-- As in 0034, counting as owed (or as waiting for a price) only sessions
-- whose payment stands.
create or replace function public.therapist_earnings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_country text;
  p public.therapy_prices;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select t.country_code into v_country from public.therapists t where t.id = me;
  p := public.therapy_price_for(v_country);
  return jsonb_build_object(
    'country_code', v_country,
    'share', public.therapist_share(),
    'rate', case when v_country is null then null else jsonb_build_object(
      'currency', p.currency,
      'fee_minor', round(p.price_minor * public.therapist_share()),
      'country_code', v_country) end,
    'rates', public.therapist_licence_rows(me),
    'owed', (
      select coalesce(jsonb_agg(jsonb_build_object('currency', x.cur, 'amount_minor', x.amount, 'sessions', x.n)), '[]')
      from (
        select r.therapist_fee_currency cur, sum(r.therapist_fee_minor) amount, count(*) n
        from public.therapy_requests r
        where r.therapist_id = me and r.status = 'completed'
          and r.therapist_fee_minor is not null and r.payout_id is null
          and r.payment_status in ('paid', 'waived', 'not_required')
        group by 1
      ) x
    ),
    'unpriced_sessions', (
      select count(*) from public.therapy_requests r
      where r.therapist_id = me and r.status = 'completed' and r.therapist_fee_minor is null
        and r.payment_status in ('paid', 'waived', 'not_required')
    ),
    'sessions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'scheduled_at', s.scheduled_at, 'completed_at', s.completed_at,
        'close_reason', s.close_reason, 'fee_minor', s.therapist_fee_minor,
        'currency', s.therapist_fee_currency, 'payout_id', s.payout_id,
        'client_country', s.pricing_country,
        'price_minor', s.price_cents, 'price_currency', s.currency
      ) order by s.completed_at desc), '[]')
      from (
        select * from public.therapy_requests r
        where r.therapist_id = me and r.status = 'completed'
        order by r.completed_at desc
        limit 200
      ) s
    ),
    'payouts', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p2.id, 'currency', p2.currency, 'amount_minor', p2.amount_minor,
        'sessions', p2.session_count, 'method', p2.method, 'reference', p2.reference,
        'paid_at', p2.paid_at
      ) order by p2.paid_at desc), '[]')
      from public.therapist_payouts p2 where p2.therapist_id = me
    )
  );
end;
$$;


revoke execute on function public.therapist_earnings() from public, anon;
grant execute on function public.therapist_earnings() to authenticated;

-- As in 0034, counting only sessions whose payment stands.
create or replace function public.admin_therapist_balances()
returns table (
  therapist_id uuid,
  full_name text,
  email text,
  country_code text,
  active boolean,
  agreement_accepted_at timestamptz,
  currency text,
  owed_minor bigint,
  owed_sessions integer,
  unpriced_sessions integer,
  paid_minor bigint,
  last_paid_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return query
    select t.id, t.full_name, ta.email, t.country_code, t.active,
           public.therapist_accepted_agreement(ta.email),
           c.cur,
           coalesce((select sum(r.therapist_fee_minor) from public.therapy_requests r
                     where r.therapist_id = t.id and r.status = 'completed'
                       and r.payment_status in ('paid', 'waived', 'not_required')
                       and r.payout_id is null and r.therapist_fee_currency = c.cur), 0)::bigint,
           (select count(*) from public.therapy_requests r
             where r.therapist_id = t.id and r.status = 'completed'
                       and r.payment_status in ('paid', 'waived', 'not_required')
               and r.payout_id is null and r.therapist_fee_currency = c.cur)::integer,
           (select count(*) from public.therapy_requests r
             where r.therapist_id = t.id and r.status = 'completed'
                       and r.payment_status in ('paid', 'waived', 'not_required')
               and r.therapist_fee_minor is null)::integer,
           coalesce((select sum(p.amount_minor) from public.therapist_payouts p
                     where p.therapist_id = t.id and p.currency = c.cur), 0)::bigint,
           (select max(p.paid_at) from public.therapist_payouts p where p.therapist_id = t.id)
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
    cross join lateral (
      select distinct x.cur from (
        select r.therapist_fee_currency cur from public.therapy_requests r
         where r.therapist_id = t.id and r.therapist_fee_currency is not null
        union select p.currency from public.therapist_payouts p where p.therapist_id = t.id
        union select (public.therapy_price_for(t.country_code)).currency where t.country_code is not null
      ) x where x.cur is not null
      union all
      -- A therapist with no country and nothing earned still gets a row.
      select null where t.country_code is null
        and not exists (
          select 1 from public.therapy_requests r
           where r.therapist_id = t.id and r.therapist_fee_currency is not null)
        and not exists (select 1 from public.therapist_payouts p where p.therapist_id = t.id)
    ) c
    order by t.active desc, t.full_name, c.cur;
end;
$$;


revoke execute on function public.admin_therapist_balances() from public, anon;
grant execute on function public.admin_therapist_balances() to authenticated;

-- ── 7. A payout adds up exactly what it marks ────────────────────────

-- As in 0032, with the sessions marked and totalled in one statement.
create or replace function public.admin_record_therapist_payout(
  p_therapist_id uuid,
  p_currency text,
  p_method text,
  p_reference text default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  v_id uuid;
  v_total bigint;
  v_count integer;
  v_email text;
  v_name text;
  v_label text;
  v_ref text := nullif(trim(coalesce(p_reference, '')), '');
  v_method text := case p_method when 'mpesa' then 'M-Pesa' when 'bank' then 'bank transfer'
                     when 'paypal' then 'PayPal' when 'wise' then 'Wise' else 'payment' end;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtext('therapist_payout:' || p_therapist_id::text));
  -- The payout row first, then the sessions it covers marked and added up
  -- in one statement, so the total is exactly what was marked. A failure
  -- below (nothing owed) takes the row back out with everything else.
  insert into public.therapist_payouts (therapist_id, currency, amount_minor, session_count, method, reference, note, created_by)
  values (p_therapist_id, upper(p_currency), 0, 0, p_method, v_ref,
          nullif(trim(coalesce(p_note, '')), ''), public.current_user_email())
  returning id into v_id;
  with s as (
    update public.therapy_requests r
       set payout_id = v_id
     where r.therapist_id = p_therapist_id and r.status = 'completed'
       and r.payout_id is null and r.therapist_fee_currency = upper(p_currency)
       and r.therapist_fee_minor is not null
       and r.payment_status in ('paid', 'waived', 'not_required')
    returning r.therapist_fee_minor
  )
  select coalesce(sum(s.therapist_fee_minor), 0), count(*) into v_total, v_count from s;
  if coalesce(v_count, 0) = 0 then
    raise exception 'Nothing is owed to them in %.', upper(p_currency) using errcode = '22023';
  end if;
  update public.therapist_payouts
     set amount_minor = v_total, session_count = v_count
   where id = v_id;

  select ta.email, t.full_name into v_email, v_name
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = p_therapist_id;
  v_label := public.therapy_price_label(v_total, upper(p_currency));
  if v_email is not null then
    perform public.send_app_email(
      v_email,
      care_team,
      'We’ve paid you ' || v_label,
      public.email_layout(
        'Your payment for ' || v_count || ' session' || case when v_count = 1 then '' else 's' end || '.',
        'You’ve been paid',
        'Hi ' || public.email_escape(split_part(coalesce(v_name, ''), ' ', 1))
          || ', we’ve sent you ' || public.email_escape(v_label) || ' by ' || v_method
          || ' for ' || v_count || ' session' || case when v_count = 1 then '' else 's' end || '.',
        public.email_box('#F3F6FC', 'Payment',
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Amount', public.email_escape(v_label))
          || public.email_row('Sessions', v_count::text)
          || public.email_row('Sent by', v_method)
          || coalesce(public.email_row('Reference', public.email_escape(v_ref)), '')
          || '</table>'),
        'Every session it covers is listed under Earnings at '
          || '<a href="https://therapists.mindpillars.app/">therapists.mindpillars.app</a>. '
          || 'Questions? Just reply to this email.'
      ),
      'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ',' || E'\n\n'
        || 'We’ve sent you ' || v_label || ' by ' || v_method || ' for ' || v_count
        || ' session' || case when v_count = 1 then '' else 's' end || '.'
        || coalesce(E'\n' || 'Reference: ' || v_ref, '') || E'\n\n'
        || 'Every session it covers is listed under Earnings at https://therapists.mindpillars.app/',
      'therapist-payout/' || v_id
    );
  end if;
  return v_id;
end;
$$;


revoke execute on function public.admin_record_therapist_payout(uuid, text, text, text, text) from public, anon;
grant execute on function public.admin_record_therapist_payout(uuid, text, text, text, text) to authenticated;

-- ── 8. The care team changing a payment keeps its history ────────────

-- As in 0009, but nothing about a real payment is thrown away:
--   • waived keeps the purchase (payment_ref, paid_at), so a RevenueCat
--     purchase still counts as used by confirm-session-payment and a
--     Paystack checkout still names its session;
--   • unpaid, from paid, moves the purchase to refunded_payment_ref (which
--     also flags a Paystack checkout so it can't pay again, 0035);
--   • paid keeps whatever purchase is there, or records a manual one.
-- Only a session that hasn't happened yet can be changed: a completed or
-- cancelled one has fees, payouts and refunds hanging off it.
create or replace function public.admin_set_therapy_payment(
  p_request_id uuid,
  p_payment_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  req public.therapy_requests%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if p_payment_status not in ('paid', 'waived', 'unpaid') then
    raise exception 'Unknown payment status.' using errcode = '22023';
  end if;
  select * into req from public.therapy_requests
   where id = p_request_id for update;
  if not found or req.price_cents <= 0 then
    raise exception 'This session has nothing to pay.' using errcode = '22023';
  end if;
  if req.status not in ('awaiting_payment', 'pending', 'confirmed') then
    raise exception 'Only a session that hasn’t happened yet can have its payment changed.'
      using errcode = '22023';
  end if;
  if req.payment_status = p_payment_status then
    return;
  end if;
  update public.therapy_requests
  set payment_status = p_payment_status,
      paid_at = case
        when p_payment_status = 'paid' then coalesce(paid_at, now())
        when p_payment_status = 'waived' then paid_at
      end,
      payment_ref = case
        when p_payment_status = 'paid' then coalesce(payment_ref, 'manual:' || gen_random_uuid())
        when p_payment_status = 'waived' then payment_ref
      end,
      refunded_payment_ref = case
        when p_payment_status = 'unpaid' and payment_ref is not null then payment_ref
        else refunded_payment_ref
      end
  where id = p_request_id;
end;
$$;

revoke execute on function public.admin_set_therapy_payment(uuid, text) from public, anon;
grant execute on function public.admin_set_therapy_payment(uuid, text) to authenticated;

-- ── 9. Honest emails when an account is deleted late ─────────────────

-- As in 0031, but a confirmed session cancelled less than 24 hours before
-- it was due to start (an account deleted then, or the care team
-- cancelling late) is no longer described as cancelled "with the notice
-- the policy asks for": the care team is told it's late and theirs to
-- decide. A deletion says so.
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
  -- Cancelled less than 24 hours before it was due to start: the policy
  -- doesn't promise a refund, so the care team decides.
  late boolean := old.status = 'confirmed' and old.scheduled_at is not null
                  and old.scheduled_at - public.therapy_cancel_notice() <= coalesce(new.cancelled_at, now());
  deleting boolean := coalesce(current_setting('app.therapy_account_deletion', true), '') = 'on';
begin
  select u.email::text,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), '')
    into client_email, client_name
    from auth.users u where u.id = new.user_id;
  client_first := public.therapy_client_first_name(new.user_id);
  when_text := case when new.scheduled_at is null then 'not yet scheduled'
                    else public.email_session_time(new.scheduled_at) end;
  amount := public.therapy_price_label(new.price_cents, new.currency);
  -- Paid through Paystack: name what was actually charged (0022).
  if new.payment_ref like 'paystack:%' then
    amount := coalesce((
      select public.therapy_price_label(c.amount, c.currency)
             || case when c.currency = new.currency and c.amount = new.price_cents then ''
                     else ' (' || public.therapy_price_label(new.price_cents, new.currency) || ')' end
        from public.paystack_checkouts c
       where c.reference = substr(new.payment_ref, 10)), amount);
  end if;

  perform public.send_app_email(
    care_team,
    coalesce(client_email, care_team),
    case when late then 'Paid session cancelled late — ' else 'Refund due — ' end
      || coalesce(client_name, client_email, 'a client'),
    public.email_layout(
      public.email_escape(when_text),
      'A paid session was cancelled',
      public.email_escape(coalesce(client_name, client_email, 'A client'))
        || '’s session (' || public.email_escape(when_text) || ') was cancelled '
        || case when old.status = 'pending' then 'before it was matched'
                when late then 'less than 24 hours before it was due to start'
                else 'with the notice the policy asks for' end
        || case when deleting then ', because they deleted their account' else '' end
        || '. They had paid ' || amount
        || case when late
           then '. A late cancellation isn’t refunded automatically, so it’s your call. If you do refund it, use '
           else ', so please refund it in ' end
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
      || ') was cancelled'
      || case when late then ' less than 24 hours before it was due to start' else '' end
      || case when deleting then ', because they deleted their account' else '' end
      || '. They had paid ' || amount
      || case when late
         then '. A late cancellation isn’t refunded automatically, so it’s your call.'
         else ' — please refund it.' end
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


revoke execute on function public.notify_therapy_refund_due() from public, anon, authenticated;

-- As in 0035, with the emails told it's a deletion: the setting
-- app.therapy_account_deletion is 'on' (for this transaction) while the
-- sessions are cancelled, so the refund-due email above, and the client's
-- cancellation email (notify_therapy_session_change, redefined in 0037),
-- can word one less than 24 hours ahead honestly.
create or replace function public.therapy_cancel_for_deletion(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed integer;
begin
  perform public.payments_require_server();
  perform set_config('app.therapy_account_deletion', 'on', true);
  -- Cancelled first, as the client cancelling would be, so a paid session
  -- reaches the care team for its refund (0019 sends that only for a
  -- cancellation without a close reason); the reason is added after.
  with gone as (
    update public.therapy_requests
       set status = 'cancelled',
           cancelled_at = now()
     where user_id = p_user_id
       and status in ('awaiting_payment', 'pending', 'confirmed')
    returning id
  )
  select count(*) into changed from gone;
  perform set_config('app.therapy_account_deletion', '', true);
  update public.therapy_requests
     set close_reason = 'account_deleted'
   where user_id = p_user_id
     and status = 'cancelled'
     and close_reason is null
     and cancelled_at >= now();
  return changed;
end;
$$;

revoke execute on function public.therapy_cancel_for_deletion(uuid) from public, anon, authenticated;
grant execute on function public.therapy_cancel_for_deletion(uuid) to service_role;

commit;
