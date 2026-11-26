-- 0038: fixes from the review of 0036 and 0037 (26 November 2026).
--
--  1. Settling a Paystack payment and recording its refund can't cross:
--     paystack_settle_checkout() checks the refund and attaches the payment
--     under a lock on the checkout row, the same row a refund marks first.
--  2. One start opens one checkout: paystack_open_checkout() records a new
--     checkout only if no other start recorded one for the session since
--     this one looked (the session row is locked while it decides).
--  3. Every purchase a session has ever held is remembered
--     (therapy_used_purchases), so resetting a payment twice can't free an
--     earlier RevenueCat purchase to pay for another session.
--  4. A waived session's purchase that is later refunded is recorded as
--     refunded (the waiver stays); marking that session paid again records
--     a manual payment instead of reusing the refunded one.
--  5. The first pricing country can't be overwritten by a request that
--     lost the race to set it: the winner's row is reread and checked.
--  6. A therapist taken off a session in the same update that cancels it
--     is the only one told; with no email for them, no email is sent.
--  7. Approving an application needs every check, even when the list of
--     ticked checks contains a null; a resubmission sent while the
--     application was being approved can't reopen it.
--  8. report_site_error: eviction never removes a fault reopened
--     meanwhile; a fault emailed in the last hour isn't emailed again when
--     it reopens; the six emails an hour are reserved atomically; and a
--     report that finds the log full of unseen faults is dropped (said so).
--  9. The per-person caps on saved items and session feelings are checked
--     one insert at a time per person.
--
-- Run after 0037. Safe to run more than once. Then deploy paystack-payment,
-- paystack-webhook, confirm-session-payment and session-token.

begin;

-- ── 1. Settling a payment, serialised with its refund ────────────────

-- Attaches a Paystack checkout that Paystack says succeeded (the caller
-- has checked the amount and currency) to its session. Returns
--   'paid'        the session is paid with this checkout (now, or already);
--   'not_paid'    the checkout is refunded, or unknown;
--   'unattached'  the money can't pay for its session (cancelled, or paid
--                 another way): the caller asks the care team to refund it.
-- The checkout row is locked first. A refund marks that row (refunded_at)
-- before it touches the session, so either the refund comes first and this
-- sees it, or this comes first and the refund then finds the session paid
-- with this checkout and clears it.
create or replace function public.paystack_settle_checkout(
  p_reference text,
  p_paid_at timestamptz
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.paystack_checkouts%rowtype;
  v_ref text := 'paystack:' || p_reference;
  v_paid_at timestamptz := coalesce(p_paid_at, now());
  v_current text;
begin
  perform public.payments_require_server();
  select * into c from public.paystack_checkouts
   where reference = p_reference for update;
  if not found or c.refunded_at is not null then
    return 'not_paid';
  end if;
  if exists (select 1 from public.therapy_requests r
              where r.refunded_payment_ref = v_ref) then
    return 'not_paid';
  end if;

  update public.paystack_checkouts
     set paid_at = v_paid_at
   where reference = p_reference and paid_at is null;

  if c.request_id is not null and c.user_id is not null then
    begin
      update public.therapy_requests
         set payment_status = 'paid', payment_ref = v_ref, paid_at = v_paid_at
       where id = c.request_id
         and user_id = c.user_id
         and payment_status = 'unpaid'
         and status in ('awaiting_payment', 'pending', 'confirmed');
      if found then
        return 'paid';
      end if;
    exception when unique_violation then
      -- payment_ref is unique: this checkout already paid for it.
      null;
    end;
    select r.payment_ref into v_current
      from public.therapy_requests r where r.id = c.request_id;
    if v_current = v_ref then
      return 'paid';
    end if;
  end if;
  return 'unattached';
end;
$$;

revoke execute on function public.paystack_settle_checkout(text, timestamptz) from public, anon, authenticated;
grant execute on function public.paystack_settle_checkout(text, timestamptz) to service_role;

-- ── 2. One checkout per start ────────────────────────────────────────

-- Records a new checkout for a session, unless another start recorded one
-- after this one looked ([p_seen]: the references it found, newest first
-- or in any order). Returns null when this checkout was recorded, or the
-- reference of the one another start opened meanwhile — the caller then
-- answers "payment in progress" instead of opening a second transaction.
-- The session row is locked while it decides, so two starts can't both
-- record one.
create or replace function public.paystack_open_checkout(
  p_reference text,
  p_request_id uuid,
  p_user_id uuid,
  p_amount integer,
  p_currency text,
  p_seen text[] default '{}'
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_newest_seen timestamptz;
  v_other text;
begin
  perform public.payments_require_server();
  perform 1 from public.therapy_requests where id = p_request_id for update;
  if not found then
    raise exception 'No such session.' using errcode = 'P0002';
  end if;
  select max(c.created_at) into v_newest_seen
    from public.paystack_checkouts c
   where c.reference = any (coalesce(p_seen, '{}'));
  select c.reference into v_other
    from public.paystack_checkouts c
   where c.request_id = p_request_id
     and c.user_id = p_user_id
     and c.refund_requested_at is null
     and c.refunded_at is null
     and not (c.reference = any (coalesce(p_seen, '{}')))
     and (v_newest_seen is null or c.created_at >= v_newest_seen)
   order by c.created_at desc
   limit 1;
  if v_other is not null then
    return v_other;
  end if;
  insert into public.paystack_checkouts (reference, request_id, user_id, amount, currency)
  values (p_reference, p_request_id, p_user_id, p_amount, p_currency);
  return null;
end;
$$;

revoke execute on function public.paystack_open_checkout(text, uuid, uuid, integer, text, text[]) from public, anon, authenticated;
grant execute on function public.paystack_open_checkout(text, uuid, uuid, integer, text, text[]) to service_role;

-- ── 3. Every purchase a session has held ─────────────────────────────

-- payment_ref and refunded_payment_ref hold one purchase each, so a second
-- reset to unpaid by the care team overwrote the first purchase, and
-- confirm-session-payment could then use it for another session. This
-- keeps every one, for good (rows go with the session or the account).
create table if not exists public.therapy_used_purchases (
  ref text primary key,
  request_id uuid not null references public.therapy_requests (id) on delete cascade,
  user_id uuid references auth.users (id) on delete cascade,
  recorded_at timestamptz not null default now()
);
create index if not exists therapy_used_purchases_user_idx
  on public.therapy_used_purchases (user_id);
alter table public.therapy_used_purchases enable row level security;
-- No policies: only the server reads it.
revoke all on table public.therapy_used_purchases from public, anon, authenticated;

create or replace function public.therapy_requests_note_purchases()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.therapy_used_purchases (ref, request_id, user_id)
  select r, new.id, new.user_id
    from unnest(array[new.payment_ref, new.refunded_payment_ref]) r
   where r is not null
  on conflict (ref) do nothing;
  return null;
end;
$$;

revoke execute on function public.therapy_requests_note_purchases() from public, anon, authenticated;

drop trigger if exists therapy_requests_note_purchases on public.therapy_requests;
create trigger therapy_requests_note_purchases
  after insert or update of payment_ref, refunded_payment_ref on public.therapy_requests
  for each row execute function public.therapy_requests_note_purchases();

-- The purchases sessions hold now. (One overwritten before this can't be
-- recovered.)
insert into public.therapy_used_purchases (ref, request_id, user_id)
select r.ref, r.id, r.user_id
  from (
    select id, user_id, payment_ref as ref from public.therapy_requests where payment_ref is not null
    union all
    select id, user_id, refunded_payment_ref from public.therapy_requests where refunded_payment_ref is not null
  ) r
on conflict (ref) do nothing;

-- ── 4. A waived session's refunded purchase isn't reused ─────────────

-- As in 0036, plus: a refund of a purchase a waived session still holds is
-- recorded on that session (refunded_at, refunded_payment_ref) without
-- undoing the waiver.
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

  -- A waived session keeps its purchase (0036). The waiver stands, but the
  -- refunded purchase is recorded as refunded, so marking the session paid
  -- again can't reuse it.
  update public.therapy_requests
     set refunded_at = now(),
         refunded_payment_ref = payment_ref,
         payment_ref = null,
         paid_at = null
   where user_id = p_user_id
     and payment_status = 'waived'
     and payment_ref = any (p_refs);

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

revoke execute on function public.record_therapy_refunds(uuid, text[]) from public, anon, authenticated;
grant execute on function public.record_therapy_refunds(uuid, text[]) to service_role;

-- Paystack refunds of waived sessions recorded before this.
update public.therapy_requests r
   set refunded_at = coalesce(c.refunded_at, now()),
       refunded_payment_ref = r.payment_ref,
       payment_ref = null,
       paid_at = null
  from public.paystack_checkouts c
 where r.payment_status = 'waived'
   and r.payment_ref = 'paystack:' || c.reference
   and c.refunded_at is not null;

-- As in 0036, except that marking a waived session paid reuses its
-- purchase only while that purchase stands; a refunded Paystack one is
-- kept as refunded and a manual payment is recorded.
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
  v_ref text;
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
  -- The purchase a waived session kept, unless it has been refunded since:
  -- then marking it paid records a manual payment of its own.
  v_ref := req.payment_ref;
  if v_ref like 'paystack:%' and exists (
       select 1 from public.paystack_checkouts c
        where 'paystack:' || c.reference = v_ref
          and (c.refunded_at is not null or c.refund_requested_at is not null)) then
    v_ref := null;
  end if;
  update public.therapy_requests
  set payment_status = p_payment_status,
      paid_at = case
        when p_payment_status = 'paid' and v_ref is not null then coalesce(paid_at, now())
        when p_payment_status = 'paid' then now()
        when p_payment_status = 'waived' then paid_at
      end,
      payment_ref = case
        when p_payment_status = 'paid' then coalesce(v_ref, 'manual:' || gen_random_uuid())
        when p_payment_status = 'waived' then payment_ref
      end,
      refunded_payment_ref = case
        when p_payment_status = 'unpaid' and payment_ref is not null then payment_ref
        when p_payment_status = 'paid' and payment_ref is distinct from v_ref then payment_ref
        else refunded_payment_ref
      end
  where id = p_request_id;
end;
$$;

revoke execute on function public.admin_set_therapy_payment(uuid, text) from public, anon;
grant execute on function public.admin_set_therapy_payment(uuid, text) to authenticated;

-- ── 5. The first country can't be overwritten unchecked ──────────────

-- As in 0036, but the first choice is an insert that does nothing if a row
-- appeared meanwhile; the rules are then checked against that row.
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
  -- The first choice, when there's no country on file yet. If another
  -- request (a detection, or a second choice) got there first, this one
  -- is checked against what it wrote.
  insert into public.therapy_client_countries (user_id, country_code, set_by, source)
  values (auth.uid(), v_code, 'client', 'client')
  on conflict (user_id) do nothing;
  if found then
    return public.therapy_price_quote();
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
  update public.therapy_client_countries c
     set country_code = v_code, set_by = 'client', source = 'client', updated_at = now()
   where c.user_id = auth.uid();
  return public.therapy_price_quote();
end;
$$;

revoke execute on function public.therapy_set_country(text) from public, anon;
grant execute on function public.therapy_set_country(text) to authenticated;

-- ── 6. A cancellation goes to the therapist it was booked with ───────

-- As in 0037, but a session cancelled and given to someone else in one
-- update tells only the therapist it was booked with. With no email for
-- them, no therapist email is sent.
create or replace function public.notify_therapy_session_change()
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
  therapist_name text;
  therapist_email text;
  old_therapist_name text;
  old_therapist_email text;
  when_text text;
  old_when_text text;
  moved boolean;
  reassigned boolean := old.therapist_id is not null
    and new.therapist_id is distinct from old.therapist_id;
  revision text := ((extract(epoch from now()) * 1000)::bigint)::text;
  event_key text;
  pay_client text;
  pay_therapist text;
  -- An account deleted less than 24 hours before a paid session: the
  -- care team decides about a refund, so nothing is promised (0036).
  late_deletion boolean := coalesce(current_setting('app.therapy_account_deletion', true), '') = 'on'
                           and old.status = 'confirmed' and old.scheduled_at is not null
                           and old.scheduled_at - public.therapy_cancel_notice() <= coalesce(new.cancelled_at, now());
  refund_line text;
begin
  select u.email::text into client_email
    from auth.users u where u.id = new.user_id;
  client_first := public.therapy_client_first_name(new.user_id);
  select t.full_name, ta.email
    into therapist_name, therapist_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
    where t.id = coalesce(new.therapist_id, old.therapist_id);
  if old.therapist_id is not null then
    select t.full_name, ta.email
      into old_therapist_name, old_therapist_email
      from public.therapists t
      left join public.therapist_accounts ta on ta.therapist_id = t.id
      where t.id = old.therapist_id;
  end if;
  when_text := public.email_session_time(coalesce(new.scheduled_at, old.scheduled_at));
  old_when_text := public.email_session_time(coalesce(old.scheduled_at, new.scheduled_at));

  if new.status = 'confirmed' and (
       old.status is distinct from 'confirmed'
       or old.scheduled_at is distinct from new.scheduled_at
       or old.therapist_id is distinct from new.therapist_id) then
    moved := old.status = 'confirmed';
    event_key := 'therapy-session/' || new.id || '/confirmed/'
      || extract(epoch from new.scheduled_at)::bigint || '/' || new.therapist_id
      || '/' || revision;

    if new.payment_status = 'unpaid' then
      pay_client := 'This session is ' || public.therapy_price_label(new.price_cents, new.currency)
        || '. Pay in the app to confirm your place — the Join button unlocks once it’s paid.';
      pay_therapist := 'Waiting for the client to pay. They can join once it’s paid.';
    elsif new.is_free_session then
      pay_client := 'Your first session is free — on us.';
      pay_therapist := 'Their free first session.';
    else
      pay_client := 'Nothing to pay — you’re all set.';
      pay_therapist := 'Paid.';
    end if;

    perform public.send_app_email(
      client_email,
      care_team,
      case when moved then 'Your session has changed'
        else 'You’re matched with ' || therapist_name end,
      public.email_layout(
        public.email_escape(when_text),
        case when moved then 'Your session has changed' else 'You’re matched' end,
        'Hi ' || public.email_escape(coalesce(client_first, 'there')) || ', '
          || case when moved then 'here are the new details for your session.'
             else 'we’ve found you a licensed therapist and booked your session.' end,
        public.email_box('#F3F6FC', 'Your session',
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Therapist', public.email_escape(therapist_name))
          || public.email_row('When', public.email_escape(when_text))
          || public.email_row('Length', new.duration_minutes || ' minutes')
          || public.email_row('Focus', public.email_escape(new.topic))
          || '</table>')
        || spacer
        || public.email_box('#F6F6F6', 'How to join',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || public.email_escape(pay_client)
          || ' Open the app and go to <strong style="font-weight:600;color:#191919;">'
          || 'Talk to a therapist</strong>. The Join button appears 10 minutes '
          || 'before the start — it’s a private video call, right in the app.</div>'),
        'The app shows the time in your own time zone. Need to change something? '
          || 'Just reply to this email.'
      ),
      'Hi ' || coalesce(client_first, 'there') || ','
        || E'\n\n'
        || case when moved then 'Your session has changed. The new details:'
           else 'We’ve found you a licensed therapist and booked your session.' end
        || E'\n\n'
        || 'Therapist: ' || therapist_name || E'\n'
        || 'When: ' || when_text || E'\n'
        || 'Length: ' || new.duration_minutes || ' minutes' || E'\n'
        || 'Focus: ' || new.topic
        || E'\n\n' || pay_client
        || E'\n\n'
        || 'Open the app and go to Talk to a therapist. The Join button appears '
        || '10 minutes before the start. The app shows the time in your own time zone.'
        || E'\n\n' || '— Δεν είσαι μόνος',
      event_key || '/client'
    );

    -- New to this therapist when it was someone else's until now.
    moved := moved and not reassigned;

    perform public.send_app_email(
      therapist_email,
      care_team,
      case when moved then 'Session updated — ' else 'New session — ' end || when_text,
      public.email_layout(
        public.email_escape(coalesce(client_first, 'A client') || ' · ' || when_text),
        case when moved then 'Session updated' else 'New session booked' end,
        'You have a session with <strong style="font-weight:600;color:#191919;">'
          || public.email_escape(coalesce(client_first, 'a client')) || '</strong>.',
        public.email_box('#F3F6FC', 'Session',
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Client', public.email_escape(coalesce(client_first, '—')))
          || public.email_row('When', public.email_escape(when_text))
          || public.email_row('Length', new.duration_minutes || ' minutes')
          || public.email_row('Focus', public.email_escape(new.topic))
          || public.email_row('Payment', public.email_escape(pay_therapist))
          || '</table>')
        || spacer
        || public.email_box('#F6F6F6', 'How to join',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || 'Sign in to the app with this email address and open '
          || '<strong style="font-weight:600;color:#191919;">Settings → My therapy sessions</strong>. '
          || 'The Join button appears 10 minutes before the start.</div>'),
        'Sent automatically by the Δεν είσαι μόνος care team. Questions? Just reply.'
      ),
      case when moved then 'Session updated' else 'New session booked' end
        || E'\n\n'
        || 'Client: ' || coalesce(client_first, '—') || E'\n'
        || 'When: ' || when_text || E'\n'
        || 'Length: ' || new.duration_minutes || ' minutes' || E'\n'
        || 'Focus: ' || new.topic || E'\n'
        || 'Payment: ' || pay_therapist
        || E'\n\n'
        || 'Sign in to the app with this email address and open Settings → My '
        || 'therapy sessions. The Join button appears 10 minutes before the start.',
      event_key || '/therapist'
    );

  elsif old.status = 'confirmed' and new.status = 'cancelled' then
    event_key := 'therapy-session/' || new.id || '/cancelled';
    -- The therapist it was booked with, should it have changed hands in
    -- the same update: only them, and nobody if they have no email.
    if old.therapist_id is not null then
      therapist_name := old_therapist_name;
      therapist_email := old_therapist_email;
    end if;
    refund_line := case
      when new.payment_status <> 'paid' then ''
      when late_deletion then ' It was less than 24 hours before the start, so it isn’t refunded '
        || 'automatically: the care team will look at it and reply to this email.'
      else ' Because you’d already paid, we’ll arrange your refund.' end;

    perform public.send_app_email(
      client_email,
      care_team,
      'Your session has been cancelled',
      public.email_layout(
        public.email_escape(old_when_text),
        'Session cancelled',
        'Hi ' || public.email_escape(coalesce(client_first, 'there'))
          || ', your session with ' || public.email_escape(coalesce(therapist_name, 'your therapist'))
          || ' on ' || public.email_escape(old_when_text) || ' has been cancelled.'
          || public.email_escape(refund_line),
        public.email_box('#F6F6F6', 'Whenever you’re ready',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || 'You can book again from <strong style="font-weight:600;color:#191919;">'
          || 'Talk to a therapist</strong> in the app. If you’re in crisis, please '
          || 'don’t wait — tap Get help now in the app for crisis lines near you.</div>'),
        'Questions? Just reply to this email.'
      ),
      'Hi ' || coalesce(client_first, 'there') || ','
        || E'\n\n'
        || 'Your session with ' || coalesce(therapist_name, 'your therapist')
        || ' on ' || old_when_text || ' has been cancelled.'
        || refund_line
        || E'\n\n'
        || 'You can book again from Talk to a therapist in the app whenever you’re ready.'
        || E'\n\n' || '— Δεν είσαι μόνος',
      event_key || '/client'
    );

    perform public.send_app_email(
      therapist_email,
      care_team,
      'Session cancelled — ' || old_when_text,
      public.email_layout(
        public.email_escape(old_when_text),
        'Session cancelled',
        'Your session with ' || public.email_escape(coalesce(client_first, 'a client'))
          || ' on ' || public.email_escape(old_when_text) || ' has been cancelled.',
        '',
        'Sent automatically by the Δεν είσαι μόνος care team.'
      ),
      'Your session with ' || coalesce(client_first, 'a client') || ' on '
        || old_when_text || ' has been cancelled.',
      event_key || '/therapist'
    );
    return new;
  end if;

  -- Taken off a booked session (given to someone else, or back in the
  -- queue): for this therapist it's cancelled.
  if old.status = 'confirmed' and reassigned and new.status <> 'completed' then
    perform public.send_app_email(
      old_therapist_email,
      care_team,
      'Session cancelled — ' || old_when_text,
      public.email_layout(
        public.email_escape(old_when_text),
        'Session cancelled',
        'Your session with ' || public.email_escape(coalesce(client_first, 'a client'))
          || ' on ' || public.email_escape(old_when_text) || ' has been cancelled. '
          || 'It’s no longer in your sessions, and you don’t need to do anything.',
        '',
        'Sent automatically by the Δεν είσαι μόνος care team. Questions? Just reply.'
      ),
      'Your session with ' || coalesce(client_first, 'a client') || ' on '
        || old_when_text || ' has been cancelled. It’s no longer in your sessions, '
        || 'and you don’t need to do anything.',
      'therapy-session/' || new.id || '/unassigned/' || old.therapist_id
        || '/' || revision || '/therapist'
    );
  end if;

  return new;
exception when others then
  raise warning 'therapy session % email failed: %', new.id, sqlerrm;
  return new;
end;
$$;

revoke execute on function public.notify_therapy_session_change() from public, anon, authenticated;

-- ── 7. Reviewing and resubmitting applications ───────────────────────

-- As in 0037, but a check counts as ticked only if it's in p_checks: a
-- null in the list no longer hides a missing one.
create or replace function public.admin_review_therapist_application(
  p_id uuid,
  p_approve boolean,
  p_reason text default null,
  p_checks text[] default '{}',
  p_reviewed_updated_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  app public.therapist_applications%rowtype;
  therapist uuid;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_missing text[];
  v_checks jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into app from public.therapist_applications where id = p_id for update;
  if not found then
    raise exception 'That application no longer exists.' using errcode = 'P0002';
  end if;
  if app.status <> 'pending' then
    raise exception 'That application has already been reviewed.' using errcode = '22023';
  end if;
  -- The version the admin looked at. Compared to the millisecond, as a
  -- browser keeps no finer time than that.
  if p_reviewed_updated_at is not null
     and abs(extract(epoch from (app.updated_at - p_reviewed_updated_at))) >= 0.001 then
    raise exception 'They sent their application again while you were checking it. Reload it and check the new version before you decide.'
      using errcode = '22023';
  end if;

  select coalesce(jsonb_object_agg(k, jsonb_build_object(
           'by', public.current_user_email(), 'at', now())), '{}')
    into v_checks
    from unnest(public.kyc_check_keys()) k
    where k = any (coalesce(p_checks, '{}'));

  if coalesce(p_approve, false) then
    if app.kyc_confirmed_at is null or app.id_front_path is null
       or app.selfie_path is null or app.licence_path is null then
      raise exception 'This application has no identity documents. Decline it and ask them to send it again with their ID, selfie and licence.'
        using errcode = '22023';
    end if;
    select array_agg(k) into v_missing
      from unnest(public.kyc_check_keys()) k
      where (k = any (coalesce(p_checks, '{}'))) is not true;
    if v_missing is not null then
      raise exception 'Tick every check before you approve.' using errcode = '22023';
    end if;
    if app.licence_expires_on is null or app.licence_expires_on <= current_date then
      raise exception 'Their licence has expired. Decline and ask for a current practising certificate.'
        using errcode = '22023';
    end if;
    if exists (select 1 from public.therapist_accounts ta where ta.email = app.email) then
      raise exception 'A therapist already signs in with %. Link them on the Therapists page instead.', app.email
        using errcode = '23505';
    end if;
    insert into public.therapists (
      full_name, title, credentials, bio, specialties, languages,
      years_experience, photo_url, licence_expires_on, active
    )
    values (
      app.full_name, app.title,
      left(app.credentials || ' · Licence ' || app.licence_number || ' (' || app.licence_body || ')', 200),
      app.bio, app.specialties, app.languages, app.years_experience,
      app.photo_url, app.licence_expires_on, true
    )
    returning id into therapist;
    insert into public.therapist_accounts (therapist_id, email)
    values (therapist, app.email);
    update public.therapist_applications
    set status = 'approved', therapist_id = therapist, kyc_checks = v_checks,
        reviewed_by = public.current_user_email(), reviewed_at = now(),
        updated_at = now()
    where id = p_id;
    return therapist;
  end if;

  update public.therapist_applications
  set status = 'declined', decline_reason = v_reason, kyc_checks = v_checks,
      reviewed_by = public.current_user_email(), reviewed_at = now(),
      updated_at = now()
  where id = p_id;
  perform public.send_app_email(
    app.email,
    care_team,
    'About your application to the care team',
    public.email_layout(
      'An update on your application.',
      'About your application',
      'Hi ' || public.email_escape(split_part(app.full_name, ' ', 1))
        || ', thank you for applying to join the care team on Δεν είσαι μόνος. '
        || 'We can’t approve your application as it stands.',
      case when v_reason is null then '' else
        public.email_box('#F6F6F6', 'What we need',
          '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
          || replace(public.email_escape(v_reason), E'\n', '<br>') || '</div>')
      end,
      'You can update your application and send it again at '
        || '<a href="https://therapists.mindpillars.app/">therapists.mindpillars.app</a>. '
        || 'Questions? Just reply to this email.'
    ),
    'Hi ' || split_part(app.full_name, ' ', 1) || ',' || E'\n\n'
      || 'Thank you for applying to join the care team on Δεν είσαι μόνος. '
      || 'We can’t approve your application as it stands.'
      || coalesce(E'\n\n' || v_reason, '') || E'\n\n'
      || 'You can update it and send it again at https://therapists.mindpillars.app/',
    'therapist-application-declined/' || p_id || '/' || extract(epoch from now())::bigint
  );
  return null;
end;
$$;

revoke execute on function public.admin_review_therapist_application(uuid, boolean, text, text[], timestamptz) from public, anon;
grant execute on function public.admin_review_therapist_application(uuid, boolean, text, text[], timestamptz) to authenticated;

-- As in 0037, but a resubmission that reaches the row after it was
-- approved changes nothing and says it's approved.
create or replace function public.therapist_submit_application(
  p_full_name text,
  p_title text,
  p_credentials text,
  p_licence_number text,
  p_licence_body text,
  p_country text,
  p_bio text,
  p_specialties text[],
  p_languages text[],
  p_years_experience integer,
  p_photo_url text,
  p_date_of_birth date,
  p_phone text,
  p_id_type text,
  p_id_number text,
  p_licence_expires_on date,
  p_id_front_path text,
  p_id_back_path text,
  p_selfie_path text,
  p_licence_path text,
  p_country_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  v_email text := public.current_user_email();
  v_id uuid;
  v_name text := trim(coalesce(p_full_name, ''));
  v_photo text := nullif(trim(coalesce(p_photo_url, '')), '');
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g');
  v_back text := nullif(trim(coalesce(p_id_back_path, '')), '');
  v_emailed_at timestamptz;
begin
  if auth.uid() is null or v_email is null then
    raise exception 'Confirm your email address before applying.' using errcode = '42501';
  end if;
  if public.current_therapist_id() is not null then
    raise exception 'You’re already on the care team.' using errcode = '22023';
  end if;
  if exists (select 1 from public.therapist_applications a
             where a.user_id = auth.uid() and a.status = 'approved') then
    raise exception 'Your application has already been approved.' using errcode = '22023';
  end if;
  if length(v_name) < 2 then
    raise exception 'Enter your full name.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_credentials, ''))) < 2 then
    raise exception 'Enter your qualifications.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_licence_number, ''))) < 2
     or length(trim(coalesce(p_licence_body, ''))) < 2 then
    raise exception 'Enter your licence number and the body that issued it.' using errcode = '22023';
  end if;
  if coalesce(p_country_code, '') !~ '^[A-Z]{2}$' then
    raise exception 'Choose the country you’re licensed in.' using errcode = '22023';
  end if;
  if public.therapist_accepted_agreement(v_email) is null then
    raise exception 'Read and accept the therapist agreement before you send your application.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_country, ''))) < 2 then
    raise exception 'Enter the country you’re licensed in.' using errcode = '22023';
  end if;
  if p_years_experience is not null and p_years_experience not between 0 and 70 then
    raise exception 'Years of experience should be between 0 and 70.' using errcode = '22023';
  end if;
  if not public.therapist_photo_ok(v_photo) then
    raise exception 'Upload your photo from this page.' using errcode = '22023';
  end if;
  if p_date_of_birth is null
     or p_date_of_birth > (current_date - interval '21 years')::date
     or p_date_of_birth < (current_date - interval '100 years')::date then
    raise exception 'Enter your date of birth. You need to be 21 or over to apply.' using errcode = '22023';
  end if;
  if v_phone !~ '^\+[0-9]{7,15}$' then
    raise exception 'Enter your phone number with the country code, like +254 712 345 678.' using errcode = '22023';
  end if;
  if p_id_type is null or p_id_type not in ('national_id', 'passport', 'alien_id', 'driving_licence') then
    raise exception 'Choose the kind of ID you’re using.' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_id_number, ''))) not between 3 and 40 then
    raise exception 'Enter the number on your ID.' using errcode = '22023';
  end if;
  if p_licence_expires_on is null or p_licence_expires_on <= current_date then
    raise exception 'Enter when your licence or practising certificate expires. It needs to be current.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_id_front_path) then
    raise exception 'Upload a photo of your ID.' using errcode = '22023';
  end if;
  if p_id_type <> 'passport' and not public.kyc_file_ok(v_back) then
    raise exception 'Upload a photo of the back of your ID.' using errcode = '22023';
  end if;
  if v_back is not null and not public.kyc_file_ok(v_back) then
    raise exception 'Upload the back of your ID from this page.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_selfie_path) then
    raise exception 'Upload a photo of yourself holding your ID.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_licence_path) then
    raise exception 'Upload your licence or practising certificate.' using errcode = '22023';
  end if;

  insert into public.therapist_applications as a (
    user_id, email, full_name, title, credentials, licence_number,
    licence_body, country, bio, specialties, languages, years_experience,
    photo_url, date_of_birth, phone, id_type, id_number, licence_expires_on,
    id_front_path, id_back_path, selfie_path, licence_path, kyc_confirmed_at,
    country_code
  )
  values (
    auth.uid(), v_email, v_name, nullif(trim(p_title), ''), trim(p_credentials),
    trim(p_licence_number), trim(p_licence_body), trim(p_country),
    nullif(trim(p_bio), ''), public.clean_tags(p_specialties, 12),
    public.clean_tags(p_languages, 10), p_years_experience, v_photo,
    p_date_of_birth, v_phone, p_id_type, upper(trim(p_id_number)),
    p_licence_expires_on, p_id_front_path, v_back, p_selfie_path,
    p_licence_path, now(), p_country_code
  )
  on conflict (user_id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      title = excluded.title,
      credentials = excluded.credentials,
      licence_number = excluded.licence_number,
      licence_body = excluded.licence_body,
      country = excluded.country,
      bio = excluded.bio,
      specialties = excluded.specialties,
      languages = excluded.languages,
      years_experience = excluded.years_experience,
      photo_url = excluded.photo_url,
      date_of_birth = excluded.date_of_birth,
      phone = excluded.phone,
      id_type = excluded.id_type,
      id_number = excluded.id_number,
      licence_expires_on = excluded.licence_expires_on,
      id_front_path = excluded.id_front_path,
      id_back_path = excluded.id_back_path,
      selfie_path = excluded.selfie_path,
      licence_path = excluded.licence_path,
      kyc_confirmed_at = excluded.kyc_confirmed_at,
      country_code = excluded.country_code,
      kyc_checks = '{}',
      status = 'pending',
      decline_reason = null,
      reviewed_by = null,
      reviewed_at = null,
      updated_at = now()
    -- Approved while this was on its way: it stays approved.
    where a.status <> 'approved'
  returning a.id into v_id;
  if v_id is null then
    raise exception 'Your application has already been approved.' using errcode = '22023';
  end if;

  -- The care team hears once per applicant in ten minutes, however often
  -- the form is sent again; the admin page always has the latest version.
  select a.care_team_emailed_at into v_emailed_at
    from public.therapist_applications a where a.id = v_id;
  if v_emailed_at is null or v_emailed_at < now() - interval '10 minutes' then
    update public.therapist_applications
       set care_team_emailed_at = now()
     where id = v_id;
    perform public.send_app_email(
      care_team,
      v_email,
      'New therapist application: ' || v_name,
      public.email_layout(
        'A therapist has applied to join the care team.',
        'New therapist application',
        public.email_escape(v_name) || ' has applied to join the care team.',
        public.email_box('#F3F6FC', 'Licence',
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('Number', public.email_escape(trim(p_licence_number)))
          || public.email_row('Issued by', public.email_escape(trim(p_licence_body)))
          || public.email_row('Country', public.email_escape(trim(p_country)))
          || public.email_row('Expires', to_char(p_licence_expires_on, 'DD Mon YYYY'))
          || public.email_row('Email', public.email_escape(v_email))
          || '</table>'),
        'Their ID, selfie and licence are on the admin page, under Applications. '
          || 'Check each one, and the licence with the issuing body, before you approve.'
      ),
      v_name || ' has applied to join the care team.' || E'\n\n'
        || 'Licence: ' || trim(p_licence_number) || ', issued by ' || trim(p_licence_body)
        || ' (' || trim(p_country) || '), expires ' || to_char(p_licence_expires_on, 'DD Mon YYYY')
        || E'\n' || 'Email: ' || v_email || E'\n\n'
        || 'Their ID, selfie and licence are on the admin page, under Applications. '
        || 'Check each one, and the licence with the issuing body, before you approve.',
      'therapist-application/' || v_id || '/' || extract(epoch from now())::bigint
    );
  end if;
  return v_id;
end;
$$;

revoke execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text, text) from public, anon;
grant execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text, text) to authenticated;

-- ── 8. Site faults ───────────────────────────────────────────────────

-- As in 0037, plus:
--  * eviction checks each row's status as it deletes it;
--  * a fault emailed in the last hour isn't emailed again when it reopens
--    (the duplicate check includes its own row);
--  * the six emails an hour are also reserved atomically (site_error_take
--    on 'email:all', per clock hour);
--  * a report that finds the log full of faults nobody has looked at is
--    dropped; nothing waits for room. The admin page shows the faults that
--    filled it.
create or replace function public.report_site_error(
  p_message text,
  p_stack text default null,
  p_url text default null,
  p_release text default null,
  p_context jsonb default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message text := left(trim(coalesce(p_message, '')), 500);
  v_stack text := left(coalesce(p_stack, ''), 4000);
  v_url text := left(split_part(split_part(coalesce(p_url, ''), '?', 1), '#', 1), 300);
  v_release text := left(coalesce(p_release, ''), 60);
  v_context jsonb := coalesce(p_context, '{}'::jsonb);
  v_agent text;
  v_email text := public.current_user_email();
  v_caller text := coalesce('user:' || auth.uid()::text, 'anon');
  v_fp text;
  v_shape text;
  v_status text;
  v_tell boolean := false;
begin
  if v_message = '' then
    return;
  end if;
  if not public.site_error_take(v_caller, interval '1 minute',
                                case when v_caller = 'anon' then 60 else 30 end) then
    return;
  end if;
  -- Now and then, forget old windows.
  if random() < 0.02 then
    delete from public.site_error_throttle where window_start < now() - interval '2 hours';
  end if;

  if jsonb_typeof(v_context) <> 'object' or length(v_context::text) > 2000 then
    v_context := '{}'::jsonb;
  end if;
  v_agent := left(coalesce(v_context ->> 'agent', ''), 300);
  -- Ids and numbers differ between two reports of the same fault.
  v_shape := regexp_replace(v_message,
            '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9]+', '#', 'g');
  v_fp := md5(v_shape
          || '|' || coalesce(v_context ->> 'kind', '')
          || '|' || split_part(v_stack, E'\n', 2));

  select e.status into v_status from public.site_errors e where e.fingerprint = v_fp for update;
  if found then
    update public.site_errors e
       set count = e.count + 1, last_seen_at = now(), release = v_release, url = v_url,
           user_email = coalesce(v_email, e.user_email),
           status = case when e.status = 'fixed' then 'new' else e.status end
     where e.fingerprint = v_fp;
    v_tell := v_status = 'fixed';
  else
    -- The log holds 2,000 faults. When it's full, the ones looked at and
    -- seen longest ago make room. Faults nobody has looked at yet stay; if
    -- they fill the log, this report is dropped (it isn't kept for later).
    if (select count(*) from public.site_errors) >= 2000 then
      -- The status again on the row itself: one reopened while this
      -- waited for it is new now, and stays.
      delete from public.site_errors e
       where e.fingerprint in (
         select o.fingerprint from public.site_errors o
          where o.status <> 'new'
          order by o.last_seen_at limit 100)
         and e.status <> 'new';
      if (select count(*) from public.site_errors) >= 2000 then
        return;
      end if;
    end if;
    insert into public.site_errors
      (fingerprint, message, stack, url, release, user_agent, context, user_email)
    values (v_fp, v_message, nullif(v_stack, ''), nullif(v_url, ''), nullif(v_release, ''),
            nullif(v_agent, ''), v_context - 'agent', v_email)
    on conflict (fingerprint) do update
      set count = public.site_errors.count + 1, last_seen_at = now();
    v_tell := true;
  end if;

  if v_tell
     and (select count(*) from public.site_errors e
           where e.emailed_at > now() - interval '1 hour') < 6
     and not exists (
       select 1 from public.site_errors e
        where e.emailed_at > now() - interval '1 hour'
          and regexp_replace(e.message,
                '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9]+', '#', 'g') = v_shape)
     and public.site_error_take('email:' || v_caller, interval '1 hour',
                                case when v_caller = 'anon' then 3 else 1 end)
     -- The six an hour, reserved under a lock: two reports can't both
     -- take the last one. Kept apart from the log, so evicting a fault
     -- doesn't give its email back.
     and public.site_error_take('email:all', interval '1 hour', 6) then
    update public.site_errors e set emailed_at = now() where e.fingerprint = v_fp;
    perform public.therapist_site_email(
      public.care_team_email(),
      null,
      'Therapist site fault: ' || left(v_message, 90),
      case when v_status = 'fixed' then 'A fixed fault is back' else 'Something failed on the therapist site' end,
      'Someone using the therapist site hit a fault. They were shown a plain message and a way to carry on; this is what happened underneath.',
      'What we know',
      jsonb_build_array(
        jsonb_build_array('Fault', v_message),
        jsonb_build_array('Page', v_url),
        jsonb_build_array('Who', coalesce(v_email, 'Not signed in')),
        jsonb_build_array('Kind', v_context ->> 'kind'),
        jsonb_build_array('Release', v_release),
        jsonb_build_array('Browser', v_agent),
        jsonb_build_array('Where', left(v_stack, 600))
      ),
      'Every fault is on the admin page, under Therapy → Site faults, with how often it has happened. In the SQL editor: select * from site_errors order by last_seen_at desc;',
      null,
      'site-error/' || v_fp || '/' || extract(epoch from now())::bigint
    );
  end if;
exception when others then
  raise warning 'report_site_error failed: %', sqlerrm;
end;
$$;

revoke execute on function public.report_site_error(text, text, text, text, jsonb) from public;
grant execute on function public.report_site_error(text, text, text, text, jsonb) to anon, authenticated;

-- ── 9. Per-person caps, one insert at a time ─────────────────────────

-- As in 0037, serialised per person and table.
create or replace function public.user_rows_cap()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_limit integer := tg_argv[0]::integer;
  v_count integer;
begin
  if current_user not in ('anon', 'authenticated') or new.user_id is null then
    return new;
  end if;
  -- One insert at a time per person and table, so two at once can't both
  -- count one under the cap. Held until the transaction ends.
  perform pg_advisory_xact_lock(hashtext(tg_table_name), hashtext(new.user_id::text));
  execute format('select count(*) from (select 1 from %I.%I where user_id = $1 limit %s) x',
                 tg_table_schema, tg_table_name, v_limit)
    into v_count using new.user_id;
  if v_count >= v_limit then
    raise exception 'You’ve reached the limit here. Remove a few and try again.'
      using errcode = '54000';
  end if;
  return new;
end;
$$;

revoke execute on function public.user_rows_cap() from public, anon, authenticated;

commit;
