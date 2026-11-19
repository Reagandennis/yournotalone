-- 0035: fixes from the 19 November 2026 review.
--
--  1. A client's new request can't carry values only the server sets: the
--     therapist's fee, a payout, refund and join times.
--  2. Deleting an account keeps the sessions and payments it had — what
--     therapists are owed, and purchase records kept for tax — without the
--     person: their words go, the rows stay.
--  3. A refunded Paystack checkout is never attached to a session again.
--  4. The care app's request list says when each request was sent.
--  5. The client's country comes from where the phone is — its SIM, then
--     its time zone — before the store account (the owner's call, 19 Nov).
--  6. Practice totals count every session, not the last four months.
--
-- Safe to run more than once.

-- ── 1. Server-owned columns on a new request ─────────────────────────

-- The insert trigger (0023) resets most of what a client could send; these
-- came later and weren't on its list. Without this a client posting to the
-- API directly could set what their therapist is paid, mark the session as
-- already paid out, or pre-fill the join times that decide a no-show.
create or replace function public.therapy_requests_insert_server_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.therapist_fee_minor := null;
    new.therapist_fee_currency := null;
    new.payout_id := null;
    new.refunded_at := null;
    new.refunded_payment_ref := null;
    new.client_joined_at := null;
    new.therapist_joined_at := null;
    new.reminder_sent_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_insert_server_columns on public.therapy_requests;
create trigger therapy_requests_insert_server_columns
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_insert_server_columns();

-- ── 2. Deleting an account keeps its sessions and payments ───────────

-- Until now deleting the auth user deleted every session and checkout it
-- had, which took completed sessions out of what their therapist is owed
-- and the payment records with them. The rows now stay, without the user.
alter table public.therapy_requests alter column user_id drop not null;
alter table public.therapy_requests
  drop constraint if exists therapy_requests_user_id_fkey;
alter table public.therapy_requests
  add constraint therapy_requests_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete set null;

alter table public.paystack_checkouts alter column user_id drop not null;
alter table public.paystack_checkouts
  drop constraint if exists paystack_checkouts_user_id_fkey;
alter table public.paystack_checkouts
  add constraint paystack_checkouts_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete set null;

-- What the person wrote goes with them; dates, prices, the therapist and
-- the outcome stay for the books.
create or replace function public.therapy_requests_forget_client()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.user_id is not null and new.user_id is null then
    new.topic := 'Account deleted';
    new.note := null;
    new.client_summary := null;
    new.availability := '{}';
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_forget_client on public.therapy_requests;
create trigger therapy_requests_forget_client
  before update of user_id on public.therapy_requests
  for each row execute function public.therapy_requests_forget_client();

alter table public.therapy_requests
  drop constraint if exists therapy_requests_close_reason_check;
alter table public.therapy_requests
  add constraint therapy_requests_close_reason_check
  check (close_reason is null or close_reason in (
    'auto_completed', 'client_no_show', 'therapist_no_show',
    'nobody_joined', 'unpaid', 'account_deleted'));

-- Sessions still to come are cancelled before the account goes, while the
-- client's details still exist for the emails: the therapist hears, and a
-- paid one reaches the care team for a refund, as with any cancellation.
-- Called by the delete-account function.
create or replace function public.therapy_cancel_for_deletion(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed integer;
begin
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

-- ── 3. A refunded checkout stays refunded ────────────────────────────

-- The app's "check payment" looks again at every checkout opened for a
-- session that hasn't been flagged for a refund. A refund recorded on the
-- session now flags its checkout too, so a checkout Paystack still reports
-- as successful can't pay for the session a second time.
create or replace function public.therapy_requests_flag_refunded_checkout()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.refunded_payment_ref is distinct from old.refunded_payment_ref
     and new.refunded_payment_ref like 'paystack:%' then
    update public.paystack_checkouts
       set refund_requested_at = coalesce(refund_requested_at, now())
     where reference = substr(new.refunded_payment_ref, length('paystack:') + 1);
  end if;
  return null;
end;
$$;

drop trigger if exists therapy_requests_flag_refunded_checkout on public.therapy_requests;
create trigger therapy_requests_flag_refunded_checkout
  after update of refunded_payment_ref on public.therapy_requests
  for each row execute function public.therapy_requests_flag_refunded_checkout();

-- Refunds recorded before this migration.
update public.paystack_checkouts c
   set refund_requested_at = coalesce(c.refund_requested_at, r.refunded_at, now())
  from public.therapy_requests r
 where r.refunded_payment_ref = 'paystack:' || c.reference
   and c.refund_requested_at is null;

-- ── 4. When a request was sent, for the care app ─────────────────────

-- As in 0034, with submitted_at at the end: without it every request a
-- client cancelled read "Not sent", paid or not, and waiting times counted
-- from the unpaid draft.
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
  close_reason text,
  client_joined_at timestamptz,
  therapist_joined_at timestamptz,
  client_rating smallint,
  client_comment text,
  therapist_rating smallint,
  therapist_comment text,
  therapist_flags text[],
  pricing_country text,
  charge_minor integer,
  charge_currency text,
  therapist_fee_minor integer,
  therapist_fee_currency text,
  submitted_at timestamptz
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
         r.close_reason, r.client_joined_at, r.therapist_joined_at,
         cr.rating, cr.comment, tr.rating, tr.comment, tr.flags,
         r.pricing_country,
         r.charge_minor, r.charge_currency,
         r.therapist_fee_minor, r.therapist_fee_currency,
         r.submitted_at
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

revoke execute on function public.admin_list_therapy_requests() from public, anon;
grant execute on function public.admin_list_therapy_requests() to authenticated;

-- ── 5. The client's country: where the phone is ──────────────────────

-- The time zone's country, worked out on the phone from its automatic time
-- zone (an iPhone has no SIM country to give).
alter table public.therapy_client_countries
  add column if not exists zone_country text;
alter table public.therapy_client_countries
  drop constraint if exists therapy_client_countries_source_check;
alter table public.therapy_client_countries
  add constraint therapy_client_countries_source_check
  check (source in ('store', 'sim', 'zone', 'region', 'client', 'admin'));

-- As in 0034, with the phone's location first: its SIM (where its plan
-- is), then its time zone (where it is), then the store account, then the
-- region setting. A Kenyan with a US Apple ID pays the Kenyan price. The
-- country still fixes at the first paid session, and the care team's
-- choice still wins.
drop function if exists public.therapy_detect_country(text, text, text, text);
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
            and not public.therapy_country_locked(auth.uid());
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

-- As in 0034, with the refusal saying where the country now comes from.
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
    from public.therapy_client_countries c where c.user_id = auth.uid();
  if v_current is distinct from v_code then
    if public.therapy_country_locked(auth.uid()) then
      raise exception 'Your country is set from your first session. Reply to any of our emails if it has changed.'
        using errcode = 'P0001';
    end if;
    if coalesce(v_source, 'client') <> 'client' then
      raise exception 'Your country comes from where your phone is. If it’s wrong, reply to any of our emails.'
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

-- As in 0034, with the time zone's country.
create or replace function public.admin_client_country(p_email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
  v_user uuid;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account uses that email.' using errcode = 'P0002';
  end if;
  -- country_code is null when nothing has been detected or set yet.
  select jsonb_build_object(
    'country_code', c.country_code, 'source', c.source, 'set_by', c.set_by,
    'store_country', c.store_country, 'sim_country', c.sim_country,
    'zone_country', c.zone_country,
    'region_country', c.region_country, 'platform', c.platform,
    'detected_at', c.detected_at, 'updated_at', c.updated_at
  ) into result
  from public.therapy_client_countries c
  where c.user_id = v_user;
  return coalesce(result, jsonb_build_object('country_code', null))
         || jsonb_build_object('locked', public.therapy_country_locked(v_user));
end;
$$;

revoke execute on function public.therapy_detect_country(text, text, text, text, text) from public, anon;
grant execute on function public.therapy_detect_country(text, text, text, text, text) to authenticated;
revoke execute on function public.therapy_set_country(text) from public, anon;
grant execute on function public.therapy_set_country(text) to authenticated;
revoke execute on function public.admin_client_country(text) from public, anon;
grant execute on function public.admin_client_country(text) to authenticated;

-- ── 6. Practice totals for all time ──────────────────────────────────

-- Home's "N sessions in all" and the practice screen's minutes were summed
-- from the last 120 days the app fetches. These are the account's totals.
create or replace function public.practice_totals()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'sessions', count(*),
    'minutes', coalesce(sum(p.minutes), 0)
  )
  from public.practice_sessions p
  where p.user_id = auth.uid();
$$;

revoke execute on function public.practice_totals() from public, anon;
grant execute on function public.practice_totals() to authenticated;
