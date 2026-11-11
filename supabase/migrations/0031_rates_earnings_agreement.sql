-- 0031: Prices and therapist fees by country, earnings and payouts, and the
-- therapist agreement.
--
-- Prices. What a client pays depends on their country, from
-- public.therapy_prices: a price shown in their currency, and the amount
-- Paystack charges (the account settles in Kenyan shillings, so that stays
-- KES). The row for '*' is everyone else, and starts at today's US$20 /
-- Ksh 2,600, so nothing changes until an admin adds a country. A client's
-- country is kept in public.therapy_client_countries; they pick it in the app
-- and can change it until their first paid session, after which only an admin
-- can. Each session keeps the price it was booked at. Emails now print the
-- session's own currency instead of always "$".
--
-- Therapist fees. What a therapist earns per session depends on their
-- country (therapists.country_code), from public.therapist_rates. The fee is
-- written on the session when it's completed, including when the therapist
-- waited and the client never joined, and never for a therapist no-show.
-- Sessions completed while no rate was set for that country get one when an
-- admin sets it. Admins record payouts (public.therapist_payouts), which
-- settle everything owed in one currency and email the therapist a
-- statement.
--
-- The agreement. Therapists accept the therapist agreement (its text is on
-- the therapist site; therapist_agreement_version() names the current one)
-- by typing their name. An application can't be sent without it, and a
-- therapist who hasn't accepted the current version can't be given a new
-- session.
--
-- Paste-run this in the Supabase dashboard → SQL Editor after 0029 and
-- 0030. Safe to re-run. Then redeploy paystack-payment, which now charges each session's
-- own amount.

-- ── Formatting ───────────────────────────────────────────────────────

-- '£45', 'US$20', 'Ksh 2,600', 'EUR 49.50'.
create or replace function public.therapy_price_label(p_minor bigint, p_currency text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case upper(coalesce(p_currency, 'USD'))
           when 'USD' then 'US$'
           when 'GBP' then '£'
           when 'EUR' then '€'
           when 'KES' then 'Ksh '
           when 'UGX' then 'USh '
           when 'TZS' then 'TSh '
           when 'NGN' then '₦'
           when 'ZAR' then 'R'
           when 'CAD' then 'CA$'
           when 'AUD' then 'A$'
           else upper(p_currency) || ' '
         end
      || case when coalesce(p_minor, 0) % 100 = 0
              then to_char(coalesce(p_minor, 0) / 100, 'FM999,999,990')
              else to_char(p_minor / 100.0, 'FM999,999,990.00')
         end;
$$;

-- ── Client prices ────────────────────────────────────────────────────

create table if not exists public.therapy_prices (
  -- An ISO country code, or '*' for everywhere without its own row.
  country_code text primary key check (country_code ~ '^([A-Z]{2}|\*)$'),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  price_minor integer not null check (price_minor between 100 and 100000000),
  charge_currency text not null default 'KES' check (charge_currency ~ '^[A-Z]{3}$'),
  charge_minor integer not null check (charge_minor between 100 and 100000000),
  updated_by text,
  updated_at timestamptz not null default now()
);
alter table public.therapy_prices enable row level security;
-- No policies: read through therapy_price_quote() and the admin functions.

insert into public.therapy_prices (country_code, currency, price_minor, charge_currency, charge_minor)
values ('*', 'USD', 2000, 'KES', 260000)
on conflict (country_code) do nothing;

create table if not exists public.therapy_client_countries (
  user_id uuid primary key references auth.users (id) on delete cascade,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  set_by text not null default 'client',
  updated_at timestamptz not null default now()
);
alter table public.therapy_client_countries enable row level security;

alter table public.therapy_requests
  add column if not exists pricing_country text,
  add column if not exists charge_minor integer,
  add column if not exists charge_currency text,
  add column if not exists therapist_fee_minor integer,
  add column if not exists therapist_fee_currency text;

-- The price row for a country, or the '*' row.
create or replace function public.therapy_price_for(p_country text)
returns public.therapy_prices
language sql
stable
security definer
set search_path = ''
as $$
  select p.* from public.therapy_prices p
  where p.country_code in (coalesce(p_country, '*'), '*')
  order by (p.country_code = '*')
  limit 1;
$$;

-- Whether this person has paid for a session, so their country is fixed.
create or replace function public.therapy_country_locked(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.therapy_requests r
    where r.user_id = p_user and r.payment_status = 'paid'
  );
$$;

-- What the signed-in person would pay, for the app to show.
create or replace function public.therapy_price_quote()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country text;
  p public.therapy_prices;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select c.country_code into v_country
    from public.therapy_client_countries c where c.user_id = auth.uid();
  p := public.therapy_price_for(v_country);
  return jsonb_build_object(
    'country', v_country,
    'can_change', not public.therapy_country_locked(auth.uid()),
    'currency', p.currency,
    'price_minor', p.price_minor,
    'charge_currency', p.charge_currency,
    'charge_minor', p.charge_minor,
    'priced_countries', (
      select coalesce(jsonb_agg(x.country_code order by x.country_code), '[]')
      from public.therapy_prices x where x.country_code <> '*'
    )
  );
end;
$$;

-- The client picks their country; fixed once they've paid for a session.
create or replace function public.therapy_set_country(p_country text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := upper(trim(coalesce(p_country, '')));
  v_current text;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if v_code !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  select c.country_code into v_current
    from public.therapy_client_countries c where c.user_id = auth.uid();
  if v_current is distinct from v_code and public.therapy_country_locked(auth.uid()) then
    raise exception 'Your country is set from your first session. Reply to any of our emails if it has changed.'
      using errcode = 'P0001';
  end if;
  insert into public.therapy_client_countries (user_id, country_code)
  values (auth.uid(), v_code)
  on conflict (user_id) do update
  set country_code = excluded.country_code, set_by = 'client', updated_at = now();
  return public.therapy_price_quote();
end;
$$;

-- Stamps each new session with the price for the client's country. Runs
-- after therapy_requests_before_insert (triggers fire in name order), which
-- sets everything else.
create or replace function public.therapy_requests_price()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.therapy_prices;
begin
  select c.country_code into new.pricing_country
    from public.therapy_client_countries c where c.user_id = new.user_id;
  p := public.therapy_price_for(new.pricing_country);
  new.price_cents := p.price_minor;
  new.currency := p.currency;
  new.charge_minor := p.charge_minor;
  new.charge_currency := p.charge_currency;
  return new;
end;
$$;

drop trigger if exists therapy_requests_price on public.therapy_requests;
create trigger therapy_requests_price
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_price();

-- ── Therapist fees ───────────────────────────────────────────────────

alter table public.therapists
  add column if not exists country_code text check (country_code ~ '^[A-Z]{2}$');
alter table public.therapist_applications
  add column if not exists country_code text check (country_code ~ '^[A-Z]{2}$');

create table if not exists public.therapist_rates (
  country_code text primary key check (country_code ~ '^([A-Z]{2}|\*)$'),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  fee_minor integer not null check (fee_minor between 0 and 100000000),
  updated_by text,
  updated_at timestamptz not null default now()
);
alter table public.therapist_rates enable row level security;

create table if not exists public.therapist_payouts (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete restrict,
  currency text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  session_count integer not null,
  method text not null check (method in ('mpesa', 'bank', 'paypal', 'wise', 'other')),
  reference text check (length(reference) <= 120),
  note text check (length(note) <= 500),
  paid_at timestamptz not null default now(),
  created_by text
);
alter table public.therapist_payouts enable row level security;

alter table public.therapy_requests
  add column if not exists payout_id uuid references public.therapist_payouts (id) on delete set null;

create index if not exists therapy_requests_earned_idx
  on public.therapy_requests (therapist_id, completed_at)
  where status = 'completed';

-- The fee row for a therapist, by their country, or the '*' row. Null if
-- neither is set.
create or replace function public.therapist_rate_for(p_therapist uuid)
returns public.therapist_rates
language sql
stable
security definer
set search_path = ''
as $$
  select r.* from public.therapist_rates r
  where r.country_code in (
    coalesce((select t.country_code from public.therapists t where t.id = p_therapist), '*'), '*')
  order by (r.country_code = '*')
  limit 1;
$$;

-- Writes the fee on a session as it's completed. A therapist no-show is
-- never completed (0016), so it never earns.
create or replace function public.therapy_requests_therapist_fee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rate public.therapist_rates;
begin
  if new.status = 'completed' and old.status is distinct from 'completed'
     and new.therapist_id is not null and new.therapist_fee_minor is null then
    rate := public.therapist_rate_for(new.therapist_id);
    if rate.country_code is not null then
      new.therapist_fee_minor := rate.fee_minor;
      new.therapist_fee_currency := rate.currency;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_therapist_fee on public.therapy_requests;
create trigger therapy_requests_therapist_fee
  before update on public.therapy_requests
  for each row execute function public.therapy_requests_therapist_fee();

-- Fills in the fee on completed, unpaid-out sessions that have none, for
-- every therapist a rate now covers.
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
  set therapist_fee_minor = (public.therapist_rate_for(r.therapist_id)).fee_minor,
      therapist_fee_currency = (public.therapist_rate_for(r.therapist_id)).currency
  where r.status = 'completed'
    and r.therapist_id is not null
    and r.therapist_fee_minor is null
    and r.payout_id is null
    and (public.therapist_rate_for(r.therapist_id)).country_code is not null;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- ── The agreement ────────────────────────────────────────────────────

-- Keep in step with AGREEMENT_VERSION on the therapist site. Change both
-- when the agreement changes: everyone is asked to accept it again, and
-- nobody can be given a new session until they have.
create or replace function public.therapist_agreement_version()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-11-11';
$$;

create table if not exists public.therapist_agreement_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  email text not null check (email = lower(trim(email))),
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  version text not null,
  user_agent text check (length(user_agent) <= 400),
  accepted_at timestamptz not null default now(),
  unique (email, version)
);
alter table public.therapist_agreement_acceptances enable row level security;

create or replace function public.therapist_accepted_agreement(p_email text)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select a.accepted_at from public.therapist_agreement_acceptances a
  where a.email = lower(p_email) and a.version = public.therapist_agreement_version();
$$;

-- Accepting, signed by typing their name.
create or replace function public.therapist_accept_agreement(
  p_version text,
  p_full_name text,
  p_user_agent text default null
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := public.current_user_email();
  v_at timestamptz;
begin
  if auth.uid() is null or v_email is null then
    raise exception 'Confirm your email address first.' using errcode = '42501';
  end if;
  if p_version is distinct from public.therapist_agreement_version() then
    raise exception 'The agreement has changed since you opened this page. Reload it and read it again.'
      using errcode = '22023';
  end if;
  if length(trim(coalesce(p_full_name, ''))) < 2 then
    raise exception 'Type your full name to sign.' using errcode = '22023';
  end if;
  insert into public.therapist_agreement_acceptances (user_id, email, full_name, version, user_agent)
  values (auth.uid(), v_email, left(trim(p_full_name), 120), p_version, left(p_user_agent, 400))
  on conflict (email, version) do nothing;
  select public.therapist_accepted_agreement(v_email) into v_at;
  return v_at;
end;
$$;

-- A therapist who hasn't accepted the current agreement can't be given a
-- new session. Sessions already booked are left alone.
create or replace function public.therapy_requests_agreement_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_name text;
begin
  if new.status = 'confirmed' and new.therapist_id is not null
     and (old.status is distinct from 'confirmed'
          or old.therapist_id is distinct from new.therapist_id) then
    select ta.email, t.full_name into v_email, v_name
      from public.therapists t
      left join public.therapist_accounts ta on ta.therapist_id = t.id
     where t.id = new.therapist_id;
    if v_email is null or public.therapist_accepted_agreement(v_email) is null then
      raise exception '% hasn’t accepted the therapist agreement yet, so they can’t be given sessions. Ask them to sign in at therapists.techgetafrica.com and accept it.',
        coalesce(v_name, 'This therapist') using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_agreement_check on public.therapy_requests;
create trigger therapy_requests_agreement_check
  before update on public.therapy_requests
  for each row execute function public.therapy_requests_agreement_check();

-- An approved applicant's country goes onto their therapist profile.
create or replace function public.therapist_applications_country()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'approved' and new.therapist_id is not null and new.country_code is not null then
    update public.therapists set country_code = new.country_code
    where id = new.therapist_id and country_code is null;
  end if;
  return new;
end;
$$;

drop trigger if exists therapist_applications_country on public.therapist_applications;
create trigger therapist_applications_country
  after update of status on public.therapist_applications
  for each row execute function public.therapist_applications_country();

-- ── For therapists ───────────────────────────────────────────────────

-- Everything the earnings page shows: their rate, what's owed, what's been
-- paid, and the sessions behind it.
create or replace function public.therapist_earnings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  rate public.therapist_rates;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  rate := public.therapist_rate_for(me);
  return jsonb_build_object(
    'country_code', (select t.country_code from public.therapists t where t.id = me),
    'rate', case when rate.country_code is null then null else jsonb_build_object(
      'currency', rate.currency, 'fee_minor', rate.fee_minor, 'country_code', rate.country_code) end,
    'owed', (
      select coalesce(jsonb_agg(jsonb_build_object('currency', x.cur, 'amount_minor', x.amount, 'sessions', x.n)), '[]')
      from (
        select r.therapist_fee_currency cur, sum(r.therapist_fee_minor) amount, count(*) n
        from public.therapy_requests r
        where r.therapist_id = me and r.status = 'completed'
          and r.therapist_fee_minor is not null and r.payout_id is null
        group by 1
      ) x
    ),
    'unpriced_sessions', (
      select count(*) from public.therapy_requests r
      where r.therapist_id = me and r.status = 'completed' and r.therapist_fee_minor is null
    ),
    'sessions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'scheduled_at', s.scheduled_at, 'completed_at', s.completed_at,
        'close_reason', s.close_reason, 'fee_minor', s.therapist_fee_minor,
        'currency', s.therapist_fee_currency, 'payout_id', s.payout_id
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
        'id', p.id, 'currency', p.currency, 'amount_minor', p.amount_minor,
        'sessions', p.session_count, 'method', p.method, 'reference', p.reference,
        'paid_at', p.paid_at
      ) order by p.paid_at desc), '[]')
      from public.therapist_payouts p where p.therapist_id = me
    )
  );
end;
$$;

-- The fee for a country, so an applicant can see what they'd earn before
-- they sign the agreement. Null if no rate covers it yet.
create or replace function public.therapist_fee_for_country(p_country text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rate public.therapist_rates;
begin
  if public.current_user_email() is null then
    raise exception 'Confirm your email address first.' using errcode = '42501';
  end if;
  select r.* into rate from public.therapist_rates r
   where r.country_code in (upper(coalesce(p_country, '*')), '*')
   order by (r.country_code = '*')
   limit 1;
  if rate.country_code is null then
    return null;
  end if;
  return jsonb_build_object('country_code', rate.country_code, 'currency', rate.currency, 'fee_minor', rate.fee_minor);
end;
$$;

-- ── For admins ───────────────────────────────────────────────────────

create or replace function public.admin_list_rates()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'prices', (select coalesce(jsonb_agg(to_jsonb(p) order by p.country_code = '*' desc, p.country_code), '[]')
               from public.therapy_prices p),
    'therapist_rates', (select coalesce(jsonb_agg(to_jsonb(r) order by r.country_code = '*' desc, r.country_code), '[]')
                        from public.therapist_rates r)
  );
end;
$$;

create or replace function public.admin_set_therapy_price(
  p_country text,
  p_currency text,
  p_price_minor integer,
  p_charge_minor integer,
  p_charge_currency text default 'KES'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  insert into public.therapy_prices (country_code, currency, price_minor, charge_currency, charge_minor, updated_by)
  values (upper(trim(p_country)), upper(trim(p_currency)), p_price_minor,
          upper(trim(coalesce(p_charge_currency, 'KES'))), p_charge_minor, public.current_user_email())
  on conflict (country_code) do update
  set currency = excluded.currency, price_minor = excluded.price_minor,
      charge_currency = excluded.charge_currency, charge_minor = excluded.charge_minor,
      updated_by = excluded.updated_by, updated_at = now();
end;
$$;

create or replace function public.admin_delete_therapy_price(p_country text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if p_country = '*' then
    raise exception 'The price for everywhere else can be changed but not removed.' using errcode = '22023';
  end if;
  delete from public.therapy_prices where country_code = upper(trim(p_country));
end;
$$;

create or replace function public.admin_set_therapist_rate(
  p_country text,
  p_currency text,
  p_fee_minor integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  insert into public.therapist_rates (country_code, currency, fee_minor, updated_by)
  values (upper(trim(p_country)), upper(trim(p_currency)), p_fee_minor, public.current_user_email())
  on conflict (country_code) do update
  set currency = excluded.currency, fee_minor = excluded.fee_minor,
      updated_by = excluded.updated_by, updated_at = now();
  -- Sessions completed while no rate applied get this one.
  return public.therapist_fill_missing_fees();
end;
$$;

create or replace function public.admin_delete_therapist_rate(p_country text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  delete from public.therapist_rates where country_code = upper(trim(p_country));
end;
$$;

create or replace function public.admin_set_therapist_country(p_therapist_id uuid, p_country text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := nullif(upper(trim(coalesce(p_country, ''))), '');
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if v_code is not null and v_code !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  update public.therapists set country_code = v_code, updated_at = now()
  where id = p_therapist_id;
  if not found then
    raise exception 'That therapist no longer exists.' using errcode = 'P0002';
  end if;
  return public.therapist_fill_missing_fees();
end;
$$;

-- For support: a client whose country is wrong after they've paid.
create or replace function public.admin_set_client_country(p_email text, p_country text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_code text := upper(trim(coalesce(p_country, '')));
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if v_code !~ '^[A-Z]{2}$' then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account uses that email.' using errcode = 'P0002';
  end if;
  insert into public.therapy_client_countries (user_id, country_code, set_by)
  values (v_user, v_code, public.current_user_email())
  on conflict (user_id) do update
  set country_code = excluded.country_code, set_by = excluded.set_by, updated_at = now();
end;
$$;

-- One row per therapist and currency: what's owed, and their agreement.
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
                       and r.payout_id is null and r.therapist_fee_currency = c.cur), 0)::bigint,
           (select count(*) from public.therapy_requests r
             where r.therapist_id = t.id and r.status = 'completed'
               and r.payout_id is null and r.therapist_fee_currency = c.cur)::integer,
           (select count(*) from public.therapy_requests r
             where r.therapist_id = t.id and r.status = 'completed'
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
        union select (public.therapist_rate_for(t.id)).currency
      ) x where x.cur is not null
      union all
      -- A therapist with nothing priced yet still gets a row.
      select null where not exists (
        select 1 from public.therapy_requests r
         where r.therapist_id = t.id and r.therapist_fee_currency is not null)
        and (public.therapist_rate_for(t.id)).currency is null
        and not exists (select 1 from public.therapist_payouts p where p.therapist_id = t.id)
    ) c
    order by t.active desc, t.full_name, c.cur;
end;
$$;

create or replace function public.admin_list_therapist_payouts(p_therapist_id uuid default null)
returns setof public.therapist_payouts
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
    select * from public.therapist_payouts p
    where p_therapist_id is null or p.therapist_id = p_therapist_id
    order by p.paid_at desc
    limit 500;
end;
$$;

-- Settles everything owed to a therapist in one currency, and emails them
-- the statement.
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
  select sum(r.therapist_fee_minor), count(*) into v_total, v_count
    from public.therapy_requests r
   where r.therapist_id = p_therapist_id and r.status = 'completed'
     and r.payout_id is null and r.therapist_fee_currency = upper(p_currency);
  if coalesce(v_count, 0) = 0 then
    raise exception 'Nothing is owed to them in %.', upper(p_currency) using errcode = '22023';
  end if;
  insert into public.therapist_payouts (therapist_id, currency, amount_minor, session_count, method, reference, note, created_by)
  values (p_therapist_id, upper(p_currency), v_total, v_count, p_method, v_ref,
          nullif(trim(coalesce(p_note, '')), ''), public.current_user_email())
  returning id into v_id;
  update public.therapy_requests r
  set payout_id = v_id
  where r.therapist_id = p_therapist_id and r.status = 'completed'
    and r.payout_id is null and r.therapist_fee_currency = upper(p_currency);

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
          || '<a href="https://therapists.techgetafrica.com/">therapists.techgetafrica.com</a>. '
          || 'Questions? Just reply to this email.'
      ),
      'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ',' || E'\n\n'
        || 'We’ve sent you ' || v_label || ' by ' || v_method || ' for ' || v_count
        || ' session' || case when v_count = 1 then '' else 's' end || '.'
        || coalesce(E'\n' || 'Reference: ' || v_ref, '') || E'\n\n'
        || 'Every session it covers is listed under Earnings at https://therapists.techgetafrica.com/',
      'therapist-payout/' || v_id
    );
  end if;
  return v_id;
end;
$$;

-- ── Emails in the session’s own currency, and the therapist site ─────

-- Same, with the session’s own currency (was 0030_fix_paystack_receipt_emails.sql)
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

-- Same, with the session’s own currency (was 0030_fix_paystack_receipt_emails.sql)
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

-- Same, with the session’s own currency (was 0019_pay_before_booking.sql)
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
  price := public.therapy_price_label(new.price_cents, new.currency);
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

-- Same, with the session’s own currency (was 0009_therapy_platform.sql)
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
  when_text text;
  moved boolean;
  event_key text;
  pay_client text;
  pay_therapist text;
begin
  select u.email::text into client_email
    from auth.users u where u.id = new.user_id;
  client_first := public.therapy_client_first_name(new.user_id);
  select t.full_name, ta.email
    into therapist_name, therapist_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
    where t.id = coalesce(new.therapist_id, old.therapist_id);
  when_text := public.email_session_time(coalesce(new.scheduled_at, old.scheduled_at));

  if new.status = 'confirmed' and (
       old.status is distinct from 'confirmed'
       or old.scheduled_at is distinct from new.scheduled_at
       or old.therapist_id is distinct from new.therapist_id) then
    moved := old.status = 'confirmed';
    event_key := 'therapy-session/' || new.id || '/confirmed/'
      || extract(epoch from new.scheduled_at)::bigint || '/' || new.therapist_id;

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

    perform public.send_app_email(
      client_email,
      care_team,
      'Your session has been cancelled',
      public.email_layout(
        public.email_escape(when_text),
        'Session cancelled',
        'Hi ' || public.email_escape(coalesce(client_first, 'there'))
          || ', your session with ' || public.email_escape(coalesce(therapist_name, 'your therapist'))
          || ' on ' || public.email_escape(when_text) || ' has been cancelled.'
          || case when new.payment_status = 'paid'
             then ' Because you’d already paid, we’ll arrange your refund.' else '' end,
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
        || ' on ' || when_text || ' has been cancelled.'
        || case when new.payment_status = 'paid'
           then ' Because you’d already paid, we’ll arrange your refund.' else '' end
        || E'\n\n'
        || 'You can book again from Talk to a therapist in the app whenever you’re ready.'
        || E'\n\n' || '— Δεν είσαι μόνος',
      event_key || '/client'
    );

    perform public.send_app_email(
      therapist_email,
      care_team,
      'Session cancelled — ' || when_text,
      public.email_layout(
        public.email_escape(when_text),
        'Session cancelled',
        'Your session with ' || public.email_escape(coalesce(client_first, 'a client'))
          || ' on ' || public.email_escape(when_text) || ' has been cancelled.',
        '',
        'Sent automatically by the Δεν είσαι μόνος care team.'
      ),
      'Your session with ' || coalesce(client_first, 'a client') || ' on '
        || when_text || ' has been cancelled.',
      event_key || '/therapist'
    );
  end if;

  return new;
exception when others then
  raise warning 'therapy session % email failed: %', new.id, sqlerrm;
  return new;
end;
$$;

-- Same, with the session’s own currency (was 0019_pay_before_booking.sql)
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
              || public.therapy_price_label(r.price_cents, r.currency) || ' payment for this session '
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
            || 'rescheduled at least 24 hours ahead isn’t refunded. The '
            || public.therapy_price_label(r.price_cents, r.currency) || ' payment for this session has been used.'
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
          'They had paid ' || public.therapy_price_label(r.price_cents, r.currency)
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

-- Same, with the session’s own currency (was 0021_paystack_payments.sql)
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

-- Same, with the session’s own currency (was 0013_therapy_refund_reversals.sql)
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

-- Same, plus the currency (was 0010_session_notifications.sql)
create or replace function public.session_notification_data(
  r public.therapy_requests,
  p_role text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'request_id', r.id,
    'role', p_role,
    'scheduled_at', r.scheduled_at,
    'duration_minutes', r.duration_minutes,
    'topic', r.topic,
    'payment_status', r.payment_status,
    'price_cents', r.price_cents,
    'currency', r.currency,
    'is_free_session', r.is_free_session,
    'counterpart', case
      when p_role = 'client' then
        (select t.full_name from public.therapists t where t.id = r.therapist_id)
      else public.therapy_client_first_name(r.user_id)
    end
  );
$$;

-- Same, plus the agreement and country (was 0029_therapist_kyc.sql)
create or replace function public.therapist_portal_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'email', public.current_user_email(),
    'is_admin', public.is_admin(),
    'agreement', jsonb_build_object(
      'version', public.therapist_agreement_version(),
      'accepted_at', public.therapist_accepted_agreement(public.current_user_email())
    ),
    'therapist', (
      select jsonb_build_object(
        'id', t.id, 'full_name', t.full_name, 'title', t.title,
        'credentials', t.credentials, 'bio', t.bio,
        'specialties', t.specialties, 'languages', t.languages,
        'years_experience', t.years_experience, 'photo_url', t.photo_url,
        'active', t.active, 'licence_expires_on', t.licence_expires_on,
        'country_code', t.country_code
      )
      from public.therapists t where t.id = me
    ),
    'application', (
      select jsonb_build_object(
        'id', a.id, 'status', a.status, 'full_name', a.full_name,
        'title', a.title, 'credentials', a.credentials,
        'licence_number', a.licence_number, 'licence_body', a.licence_body,
        'country', a.country, 'bio', a.bio, 'specialties', a.specialties,
        'languages', a.languages, 'years_experience', a.years_experience,
        'photo_url', a.photo_url, 'decline_reason', a.decline_reason,
        'date_of_birth', a.date_of_birth, 'phone', a.phone,
        'id_type', a.id_type, 'id_number', a.id_number,
        'licence_expires_on', a.licence_expires_on,
        'country_code', a.country_code,
        'id_front_path', a.id_front_path, 'id_back_path', a.id_back_path,
        'selfie_path', a.selfie_path, 'licence_path', a.licence_path,
        'created_at', a.created_at, 'updated_at', a.updated_at
      )
      from public.therapist_applications a where a.user_id = auth.uid()
    )
  ) into result;
  return result;
end;
$$;

drop function if exists public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text);

-- Same, plus the country code and the agreement (was 0029_therapist_kyc.sql)
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
  returning a.id into v_id;

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
  return v_id;
end;
$$;

-- ── Who can call what ────────────────────────────────────────────────

revoke execute on function public.therapy_price_label(bigint, text) from public, anon;
revoke execute on function public.therapy_price_for(text) from public, anon, authenticated;
revoke execute on function public.therapy_country_locked(uuid) from public, anon, authenticated;
revoke execute on function public.therapist_rate_for(uuid) from public, anon, authenticated;
revoke execute on function public.therapist_fill_missing_fees() from public, anon, authenticated;
revoke execute on function public.therapist_accepted_agreement(text) from public, anon, authenticated;
revoke execute on function public.therapy_requests_price() from public, anon, authenticated;
revoke execute on function public.therapy_requests_therapist_fee() from public, anon, authenticated;
revoke execute on function public.therapy_requests_agreement_check() from public, anon, authenticated;
revoke execute on function public.therapist_applications_country() from public, anon, authenticated;
revoke execute on function public.therapist_agreement_version() from public, anon;
revoke execute on function public.therapy_price_quote() from public, anon;
revoke execute on function public.therapy_set_country(text) from public, anon;
revoke execute on function public.therapist_accept_agreement(text, text, text) from public, anon;
revoke execute on function public.therapist_earnings() from public, anon;
revoke execute on function public.therapist_fee_for_country(text) from public, anon;
revoke execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text, text) from public, anon;
revoke execute on function public.admin_list_rates() from public, anon;
revoke execute on function public.admin_set_therapy_price(text, text, integer, integer, text) from public, anon;
revoke execute on function public.admin_delete_therapy_price(text) from public, anon;
revoke execute on function public.admin_set_therapist_rate(text, text, integer) from public, anon;
revoke execute on function public.admin_delete_therapist_rate(text) from public, anon;
revoke execute on function public.admin_set_therapist_country(uuid, text) from public, anon;
revoke execute on function public.admin_set_client_country(text, text) from public, anon;
revoke execute on function public.admin_therapist_balances() from public, anon;
revoke execute on function public.admin_list_therapist_payouts(uuid) from public, anon;
revoke execute on function public.admin_record_therapist_payout(uuid, text, text, text, text) from public, anon;
grant execute on function public.therapy_price_label(bigint, text) to authenticated;
grant execute on function public.therapist_agreement_version() to authenticated;
grant execute on function public.therapy_price_quote() to authenticated;
grant execute on function public.therapy_set_country(text) to authenticated;
grant execute on function public.therapist_accept_agreement(text, text, text) to authenticated;
grant execute on function public.therapist_earnings() to authenticated;
grant execute on function public.therapist_fee_for_country(text) to authenticated;
grant execute on function public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text, text) to authenticated;
grant execute on function public.admin_list_rates() to authenticated;
grant execute on function public.admin_set_therapy_price(text, text, integer, integer, text) to authenticated;
grant execute on function public.admin_delete_therapy_price(text) to authenticated;
grant execute on function public.admin_set_therapist_rate(text, text, integer) to authenticated;
grant execute on function public.admin_delete_therapist_rate(text) to authenticated;
grant execute on function public.admin_set_therapist_country(uuid, text) to authenticated;
grant execute on function public.admin_set_client_country(text, text) to authenticated;
grant execute on function public.admin_therapist_balances() to authenticated;
grant execute on function public.admin_list_therapist_payouts(uuid) to authenticated;
grant execute on function public.admin_record_therapist_payout(uuid, text, text, text, text) to authenticated;
