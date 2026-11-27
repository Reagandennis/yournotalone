-- MindPillars for Work: companies that pay for their staff.
--
-- A company (organization) pays per employee per month (PEPM) for a number
-- of seats. Each employee who joins gets premium in the app and a bundle of
-- therapy sessions a year, paid by the company. The site is
-- https://sso.mindpillars.app (repo ~/mindpillars-work).
--
--   • Joining: a company code, a work email on the company's domain, an
--     eligibility list HR uploads, or single sign-on (SAML, once Supabase
--     Pro is on). An email that isn't the account's own is proved with a
--     six-digit code.
--   • Premium: the app already honours app_metadata.premium_comp (0014).
--     A member gets premium_comp + premium_comp_source = 'org'; only those
--     marked 'org' are ever taken away, so a hand-granted comp is safe.
--   • Sessions: a new request from a covered member goes straight to the
--     care team with the fee waived (as 0023), stamped with sponsor_org_id.
--     Extra sessions over the bundle only if the company turned that on.
--   • Trial: 14 days, premium only. Sessions start once the company pays.
--   • Leavers keep their account; cover ends 30 days after removal.
--   • HR sees totals only, and nothing counted from fewer than 10 people.
--     Never names, never who booked therapy.
--   • Billing: Stripe, through the org-billing and stripe-webhook Edge
--     Functions (secrets STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET). Until
--     they are set, companies run on the trial or on a contract the care
--     team sets in the admin page.
--
-- Builds on 0009, 0014, 0019, 0023, 0031, 0034. Run in Supabase dashboard →
-- SQL Editor (safe to re-run).

-- ── 1. Tables ────────────────────────────────────────────────────────

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  -- Used in invite links: sso.mindpillars.app/join/<slug>.
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{2,60}$'),
  country_code text references public.countries (code),
  employee_count integer check (employee_count between 1 and 1000000),
  -- self_serve: signed up and pays online. contract: set up by the care team.
  plan text not null default 'self_serve' check (plan in ('self_serve', 'contract')),
  status text not null default 'trial'
    check (status in ('trial', 'active', 'past_due', 'paused', 'ended')),
  trial_ends_at timestamptz,
  -- When the company first paid; session bundles renew every year from it.
  started_at timestamptz,
  seats integer not null default 5 check (seats between 1 and 1000000),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  -- Monthly list price per seat. Annual billing takes the discount off it.
  pepm_minor integer not null check (pepm_minor between 0 and 100000000),
  billing_interval text not null default 'month' check (billing_interval in ('month', 'year')),
  annual_discount numeric(4, 3) not null default 0.15 check (annual_discount between 0 and 0.9),
  sessions_per_year integer not null default 6 check (sessions_per_year between 0 and 100),
  overage_enabled boolean not null default false,
  join_code text unique check (join_code ~ '^[A-Z0-9]{4}-[A-Z0-9]{4}$'),
  join_code_enabled boolean not null default true,
  domain_join_enabled boolean not null default false,
  -- When on, only emails on HR's list can join, whichever way they come in.
  eligibility_required boolean not null default false,
  sso_provider_id text,
  sso_enabled boolean not null default false,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  current_period_end timestamptz,
  notes text check (length(notes) <= 4000),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.organizations enable row level security;

create table if not exists public.organization_domains (
  domain text primary key check (domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$'),
  org_id uuid not null references public.organizations (id) on delete cascade,
  added_by text,
  created_at timestamptz not null default now()
);
create index if not exists organization_domains_org on public.organization_domains (org_id);
alter table public.organization_domains enable row level security;

-- HR people. user_id is filled when the invited email signs in.
create table if not exists public.organization_admins (
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null check (email = lower(email) and email like '%@%'),
  user_id uuid references auth.users (id) on delete cascade,
  role text not null default 'admin' check (role in ('owner', 'admin')),
  invited_by text,
  created_at timestamptz not null default now(),
  primary key (org_id, email)
);
create index if not exists organization_admins_user on public.organization_admins (user_id);
alter table public.organization_admins enable row level security;

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- The email that proved they belong (null when they joined with a code).
  work_email text check (work_email = lower(work_email)),
  joined_via text not null check (joined_via in ('code', 'domain', 'list', 'sso', 'admin')),
  status text not null default 'active' check (status in ('active', 'removed')),
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  -- Cover runs until here after removal (30 days' grace).
  sponsorship_ends_at timestamptz,
  -- Set once premium has been taken away after the grace period.
  grace_closed boolean not null default false
);
create unique index if not exists organization_members_one_active
  on public.organization_members (user_id) where status = 'active';
create index if not exists organization_members_org on public.organization_members (org_id, status);
create index if not exists organization_members_email on public.organization_members (org_id, work_email);
alter table public.organization_members enable row level security;

create table if not exists public.organization_eligibility (
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null check (email = lower(email) and email like '%@%'),
  added_at timestamptz not null default now(),
  primary key (org_id, email)
);
alter table public.organization_eligibility enable row level security;

create table if not exists public.organization_email_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null,
  joined_via text not null,
  code_hash text not null,
  attempts integer not null default 0,
  sent_count integer not null default 1,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table public.organization_email_codes enable row level security;

-- "Book a demo" requests from the site.
create table if not exists public.organization_leads (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 120),
  email text not null check (email = lower(email) and email like '%@%' and length(email) <= 254),
  company text not null check (length(company) between 1 and 160),
  job_title text check (length(job_title) <= 120),
  employee_count integer check (employee_count between 1 and 10000000),
  country_code text references public.countries (code),
  phone text check (length(phone) <= 40),
  message text check (length(message) <= 2000),
  status text not null default 'new' check (status in ('new', 'contacted', 'won', 'lost')),
  admin_note text check (length(admin_note) <= 2000),
  org_id uuid references public.organizations (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.organization_leads enable row level security;

-- Price per seat by country. '*' is the base (US/UK level); a country
-- without a row is scaled from the base by its therapy price (0034).
create table if not exists public.organization_prices (
  country_code text primary key check (country_code ~ '^([A-Z]{2}|\*)$'),
  pepm_minor integer not null check (pepm_minor between 0 and 100000000),
  sessions_per_year integer check (sessions_per_year between 0 and 100),
  updated_by text,
  updated_at timestamptz not null default now()
);
alter table public.organization_prices enable row level security;
insert into public.organization_prices (country_code, pepm_minor, sessions_per_year, updated_by)
values ('*', 600, 6, '0040 default')
on conflict (country_code) do nothing;

alter table public.therapy_requests
  add column if not exists sponsor_org_id uuid references public.organizations (id) on delete set null,
  add column if not exists sponsor_overage boolean not null default false;
create index if not exists therapy_requests_sponsor
  on public.therapy_requests (sponsor_org_id, user_id, created_at) where sponsor_org_id is not null;

-- No policies on any of these: everything goes through the functions below.

-- ── 2. Small helpers ─────────────────────────────────────────────────

create or replace function public.org_site_url()
returns text language sql immutable set search_path = '' as $$
  select 'https://sso.mindpillars.app'::text;
$$;

create or replace function public.org_public_email_domain(p_domain text)
returns boolean language sql immutable set search_path = '' as $$
  select lower(coalesce(p_domain, '')) = any (array[
    'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.uk', 'ymail.com', 'outlook.com',
    'hotmail.com', 'hotmail.co.uk', 'live.com', 'msn.com', 'icloud.com', 'me.com', 'mac.com',
    'aol.com', 'proton.me', 'protonmail.com', 'pm.me', 'gmx.com', 'gmx.net', 'mail.com',
    'yandex.com', 'yandex.ru', 'zoho.com', 'tutanota.com', 'hey.com', 'fastmail.com',
    'qq.com', '163.com', 'rocketmail.com', 'privaterelay.appleid.com']);
$$;

create or replace function public.org_clean_email(p_email text)
returns text language sql immutable set search_path = '' as $$
  select case when lower(trim(coalesce(p_email, ''))) ~ '^[^@\s]+@[a-z0-9.-]+\.[a-z]{2,}$'
              then lower(trim(p_email)) end;
$$;

create or replace function public.org_new_code()
returns text language sql volatile set search_path = '' as $$
  -- No 0/O or 1/I, so it can be read out over the phone.
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + (get_byte(b, i) % 32), 1), '')
           filter (where i < 4)
         || '-' ||
         string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + (get_byte(b, i) % 32), 1), '')
           filter (where i >= 4)
  from (select extensions.gen_random_bytes(8) as b) r, generate_series(0, 7) i;
$$;

create or replace function public.org_slug_for(p_name text)
returns text language sql volatile set search_path = '' as $$
  select left(coalesce(nullif(trim(both '-' from regexp_replace(lower(p_name), '[^a-z0-9]+', '-', 'g')), ''), 'team'), 40)
         || '-' || substr(encode(extensions.gen_random_bytes(3), 'hex'), 1, 5);
$$;

create or replace function public.org_label(p_minor bigint, p_currency text)
returns text language sql immutable set search_path = '' as $$
  select public.therapy_price_label(p_minor, p_currency);
$$;

create or replace function public.org_is_admin(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.organization_admins a
                 where a.org_id = p_org and a.user_id = auth.uid())
      or public.is_admin();
$$;

create or replace function public.org_require_admin(p_org uuid)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if not public.org_is_admin(p_org) then
    raise exception 'Only your company''s HR admins can do that.' using errcode = '42501';
  end if;
end;
$$;

-- A member is covered while active, or removed but still in the grace period.
create or replace function public.org_member_current(m public.organization_members)
returns boolean language sql stable set search_path = '' as $$
  select m.status = 'active'
      or (m.status = 'removed' and m.sponsorship_ends_at is not null and m.sponsorship_ends_at > now());
$$;

-- Start of the current yearly bundle for a company.
create or replace function public.org_period_start(o public.organizations)
returns timestamptz language sql stable set search_path = '' as $$
  select case when o.started_at is null then o.created_at
              else o.started_at + make_interval(years => greatest(0,
                     floor(extract(epoch from (now() - o.started_at)) / (365.2425 * 86400))::int))
         end;
$$;

-- ── 3. Prices ────────────────────────────────────────────────────────

-- Per seat per month in US dollars, for a country. Scales the base by how
-- the country's session price compares with the US one, between 20% and
-- 125% of the base, rounded to 50 cents.
create or replace function public.org_price_for(p_country text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_code text := public.country_code_of(p_country);
  base public.organization_prices;
  own public.organization_prices;
  v_ref numeric;
  v_here numeric;
  v_ratio numeric := 1;
  v_pepm integer;
  v_sessions integer;
begin
  select * into base from public.organization_prices where country_code = '*';
  if v_code is not null then
    select * into own from public.organization_prices where country_code = v_code;
  end if;
  v_sessions := coalesce(own.sessions_per_year, base.sessions_per_year, 6);

  if own.country_code is not null then
    v_pepm := own.pepm_minor;
  else
    select p.price_minor * p.kes_per_unit into v_ref from public.therapy_prices p
     where p.country_code = 'US' and p.kes_per_unit is not null;
    if v_code is not null then
      select p.price_minor * p.kes_per_unit into v_here from public.therapy_prices p
       where p.country_code = v_code and p.kes_per_unit is not null;
    end if;
    if v_ref > 0 and v_here > 0 then
      v_ratio := least(1.25, greatest(0.2, v_here / v_ref));
    end if;
    v_pepm := greatest(100, (round(coalesce(base.pepm_minor, 600) * v_ratio / 50.0) * 50)::int);
  end if;

  return jsonb_build_object(
    'country', v_code,
    'country_name', (select c.name from public.countries c where c.code = v_code),
    'currency', 'USD',
    'pepm_minor', v_pepm,
    'pepm_label', public.org_label(v_pepm, 'USD'),
    'annual_pepm_minor', (round(v_pepm * 0.85))::int,
    'annual_pepm_label', public.org_label((round(v_pepm * 0.85))::int, 'USD'),
    'annual_discount', 0.15,
    'sessions_per_year', v_sessions,
    'min_seats', 5,
    'self_serve_max', 100,
    'trial_days', 14,
    'session_price', (
      select jsonb_build_object('currency', t.currency, 'minor', t.price_minor,
                                'label', public.therapy_price_label(t.price_minor, t.currency))
      from public.therapy_prices t
      where t.country_code = coalesce(
        (select x.country_code from public.therapy_prices x where x.country_code = v_code), '*'))
  );
end;
$$;

-- For the pricing page (anyone).
create or replace function public.org_price_quote(p_country text default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.org_price_for(p_country)
         || jsonb_build_object('countries', (
              select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.name), '[]')
              from public.countries c));
$$;

-- ── 4. Premium follows membership ────────────────────────────────────

create or replace function public.org_sync_user(p_user uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_on boolean;
  v_meta jsonb;
begin
  select exists (
    select 1 from public.organization_members m
    join public.organizations o on o.id = m.org_id
    where m.user_id = p_user
      and public.org_member_current(m)
      and o.status in ('trial', 'active', 'past_due')
  ) into v_on;

  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta from auth.users where id = p_user;
  if not found then
    return;
  end if;

  if v_on then
    -- A comp granted by hand stays as it is.
    if v_meta ->> 'premium_comp' = 'true' and coalesce(v_meta ->> 'premium_comp_source', '') <> 'org' then
      return;
    end if;
    if v_meta ->> 'premium_comp_source' = 'org' and v_meta ->> 'premium_comp' = 'true' then
      return;
    end if;
    update auth.users
       set raw_app_meta_data = v_meta || '{"premium_comp": true, "premium_comp_source": "org"}'::jsonb
     where id = p_user;
  elsif v_meta ->> 'premium_comp_source' = 'org' then
    update auth.users
       set raw_app_meta_data = v_meta - 'premium_comp' - 'premium_comp_source'
     where id = p_user;
  end if;
end;
$$;

create or replace function public.organization_members_sync()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.org_sync_user(new.user_id);
  return null;
end;
$$;

drop trigger if exists organization_members_sync on public.organization_members;
create trigger organization_members_sync
  after insert or update of status, sponsorship_ends_at, grace_closed on public.organization_members
  for each row execute function public.organization_members_sync();

create or replace function public.organizations_status_sync()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  if new.status is distinct from old.status then
    if new.status = 'active' and new.started_at is null then
      update public.organizations set started_at = now() where id = new.id;
    end if;
    for r in select distinct m.user_id from public.organization_members m
             where m.org_id = new.id and public.org_member_current(m) loop
      perform public.org_sync_user(r.user_id);
    end loop;
  end if;
  return null;
end;
$$;

drop trigger if exists organizations_status_sync on public.organizations;
create trigger organizations_status_sync
  after update of status on public.organizations
  for each row execute function public.organizations_status_sync();

create or replace function public.organizations_touch()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists organizations_touch on public.organizations;
create trigger organizations_touch before update on public.organizations
  for each row execute function public.organizations_touch();

-- Hourly: trials that ran out unpaid pause; grace periods that ended
-- take premium away.
create or replace function public.org_housekeeping()
returns void language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  update public.organizations
     set status = 'paused'
   where status = 'trial' and stripe_subscription_id is null
     and (trial_ends_at < now()
          or (trial_ends_at is null and created_at < now() - interval '14 days'));

  for r in select m.id, m.user_id from public.organization_members m
           where m.status = 'removed' and not m.grace_closed
             and m.sponsorship_ends_at is not null and m.sponsorship_ends_at <= now() loop
    update public.organization_members set grace_closed = true where id = r.id;
  end loop;

  delete from public.organization_email_codes where expires_at < now() - interval '1 day';
end;
$$;

-- ── 5. Sessions the company pays for ─────────────────────────────────

-- Whether the company pays for the signed-in person's next request:
-- {org_id, overage} or null. Only ever answers for the caller's own
-- account (the insert trigger below asks it for new.user_id, which the
-- insert policy makes the caller). Security definer, because the app's
-- role can't read the organization tables.
create or replace function public.org_sponsor_for_request(p_user uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  m public.organization_members;
  o public.organizations;
  v_used integer;
begin
  if p_user is null or p_user is distinct from auth.uid() then
    return null;
  end if;
  select mm.* into m from public.organization_members mm
  join public.organizations oo on oo.id = mm.org_id
  where mm.user_id = p_user
    and public.org_member_current(mm)
    and oo.status in ('active', 'past_due')
  order by (mm.status = 'active') desc, mm.joined_at desc
  limit 1;
  if not found then
    return null;
  end if;
  select * into o from public.organizations where id = m.org_id;

  select count(*) into v_used from public.therapy_requests r
  where r.user_id = p_user and r.sponsor_org_id = o.id
    and not r.sponsor_overage
    and r.status <> 'cancelled'
    and r.created_at >= public.org_period_start(o);

  if v_used < o.sessions_per_year then
    return jsonb_build_object('org_id', o.id, 'overage', false);
  elsif o.overage_enabled then
    return jsonb_build_object('org_id', o.id, 'overage', true);
  end if;
  return null;
end;
$$;

-- Runs after therapy_requests_before_insert, _insert_server_columns and
-- _price (triggers fire in name order). A draft from a covered member goes
-- straight to the care team with the fee waived, as with 0023.
-- Not security definer: inside one, current_user is the owner, so the
-- app-user check below would never be true. The lookup it needs is the
-- definer function above.
create or replace function public.therapy_requests_sponsor()
returns trigger
language plpgsql set search_path = '' as $$
declare
  v jsonb;
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  -- Only the server names a sponsor.
  new.sponsor_org_id := null;
  new.sponsor_overage := false;
  if new.status <> 'awaiting_payment' or new.payment_status <> 'unpaid' then
    return new;
  end if;

  v := public.org_sponsor_for_request(new.user_id);
  if v is null then
    return new;
  end if;
  new.sponsor_org_id := (v ->> 'org_id')::uuid;
  new.sponsor_overage := (v ->> 'overage')::boolean;
  new.payment_status := 'waived';
  new.status := 'pending';
  new.submitted_at := now();
  return new;
end;
$$;

drop trigger if exists therapy_requests_sponsor on public.therapy_requests;
create trigger therapy_requests_sponsor
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_sponsor();

-- The app can't set the sponsor columns itself.
create or replace function public.therapy_requests_sponsor_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.sponsor_org_id := old.sponsor_org_id;
    new.sponsor_overage := old.sponsor_overage;
  end if;
  return new;
end;
$$;
drop trigger if exists therapy_requests_sponsor_guard on public.therapy_requests;
create trigger therapy_requests_sponsor_guard
  before update on public.therapy_requests
  for each row execute function public.therapy_requests_sponsor_guard();

-- ── 6. Emails ────────────────────────────────────────────────────────

create or replace function public.org_send_email(
  p_to text, p_subject text, p_headline text, p_intro text,
  p_button_label text, p_button_url text, p_note text, p_key text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_html text;
  v_button text := '';
begin
  if p_button_url is not null then
    v_button := '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">'
      || '<a href="' || public.email_escape(p_button_url) || '" style="display:inline-block;background:#191919;color:#FFFFFF;'
      || 'font-size:15px;font-weight:600;padding:14px 26px;border-radius:12px;text-decoration:none;">'
      || public.email_escape(p_button_label) || '</a></td></tr></table>';
  end if;
  v_html := public.email_layout(
    public.email_escape(p_intro),
    public.email_escape(p_headline),
    public.email_escape(p_intro),
    v_button || case when p_note is null then '' else
      '<p style="font-size:13px;line-height:1.6;color:#6E6E73;text-align:center;padding-top:18px;margin:0;">'
      || public.email_escape(p_note) || '</p>' end,
    'MindPillars for Work · <a href="' || public.org_site_url() || '">sso.mindpillars.app</a>');
  perform public.send_app_email(
    p_to, public.care_team_email(), p_subject, v_html,
    p_headline || E'\n\n' || p_intro
      || coalesce(E'\n\n' || p_button_label || ': ' || p_button_url, '')
      || coalesce(E'\n\n' || p_note, ''),
    p_key);
end;
$$;

-- ── 7. Public: demo requests and join info ───────────────────────────

create or replace function public.org_request_demo(
  p_name text, p_email text, p_company text, p_employee_count integer default null,
  p_country text default null, p_job_title text default null, p_phone text default null,
  p_message text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := public.org_clean_email(p_email);
  v_id uuid;
begin
  if v_email is null then
    raise exception 'Please enter a valid work email.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_company), '') is null then
    raise exception 'Please add your name and company.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.organization_leads
      where email = v_email and created_at > now() - interval '1 day') >= 3
     or (select count(*) from public.organization_leads
         where created_at > now() - interval '1 hour') >= 100 then
    raise exception 'Thanks — we already have your request and will be in touch soon.' using errcode = 'P0001';
  end if;

  insert into public.organization_leads (name, email, company, job_title, employee_count, country_code, phone, message)
  values (left(trim(p_name), 120), v_email, left(trim(p_company), 160), nullif(left(trim(p_job_title), 120), ''),
          p_employee_count, public.country_code_of(p_country), nullif(left(trim(p_phone), 40), ''),
          nullif(left(trim(p_message), 2000), ''))
  returning id into v_id;

  perform public.send_app_email(
    public.care_team_email(), v_email,
    'New demo request: ' || left(trim(p_company), 80),
    public.email_layout('New demo request', 'New demo request',
      public.email_escape(trim(p_company)),
      public.email_row('Name', public.email_escape(trim(p_name)))
      || public.email_row('Email', public.email_escape(v_email))
      || public.email_row('Job title', public.email_escape(coalesce(p_job_title, '—')))
      || public.email_row('Employees', coalesce(p_employee_count::text, '—'))
      || public.email_row('Country', public.email_escape(coalesce(
           (select c.name from public.countries c where c.code = public.country_code_of(p_country)), '—')))
      || public.email_row('Phone', public.email_escape(coalesce(p_phone, '—')))
      || public.email_row('Message', public.email_escape(coalesce(p_message, '—'))),
      'Reply to this email to answer them. Leads are in the admin page → Companies.'),
    'Demo request from ' || trim(p_name) || ' (' || v_email || '), ' || trim(p_company),
    'org-lead/' || v_id);

  perform public.org_send_email(v_email, 'We got your request — MindPillars for Work',
    'Thanks, ' || split_part(trim(p_name), ' ', 1),
    'We''ll reply within one working day to find a time that suits you.',
    'See pricing', public.org_site_url() || '/pricing', null, 'org-lead-ack/' || v_id);

  return jsonb_build_object('ok', true);
end;
$$;

-- What the join page shows for an invite link or a code. Never who's in it.
create or replace function public.org_join_info(p_slug text default null, p_code text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  o public.organizations;
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if length(v_code) = 8 then
    select * into o from public.organizations
     where join_code = left(v_code, 4) || '-' || right(v_code, 4) and join_code_enabled;
  elsif nullif(trim(p_slug), '') is not null then
    select * into o from public.organizations where slug = lower(trim(p_slug));
  end if;
  if o.id is null then
    return null;
  end if;
  return jsonb_build_object(
    'name', o.name,
    'slug', o.slug,
    'active', o.status in ('trial', 'active', 'past_due'),
    'code_ok', length(v_code) = 8,
    'methods', jsonb_build_object(
      'code', o.join_code_enabled,
      'email', o.domain_join_enabled or exists (select 1 from public.organization_eligibility e where e.org_id = o.id),
      'sso', o.sso_enabled and o.sso_provider_id is not null),
    'domains', case when o.domain_join_enabled then
      (select coalesce(jsonb_agg(d.domain order by d.domain), '[]') from public.organization_domains d where d.org_id = o.id)
      else '[]'::jsonb end,
    'sessions_per_year', o.sessions_per_year);
end;
$$;

-- For the "Sign in with SSO" button: which company uses SSO for a domain.
create or replace function public.org_sso_lookup(p_email text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('name', o.name, 'domain', d.domain)
  from public.organization_domains d
  join public.organizations o on o.id = d.org_id
  where d.domain = split_part(public.org_clean_email(p_email), '@', 2)
    and o.sso_enabled and o.sso_provider_id is not null
  limit 1;
$$;

-- ── 8. Employees: join, confirm, leave, see their cover ──────────────

create or replace function public.org_add_member(p_org uuid, p_user uuid, p_email text, p_via text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations;
begin
  select * into o from public.organizations where id = p_org for update;
  if exists (select 1 from public.organization_members
             where org_id = p_org and user_id = p_user and status = 'active') then
    return;
  end if;
  if (select count(*) from public.organization_members
      where org_id = p_org and status = 'active') >= o.seats then
    raise exception 'All of %''s seats are taken. Ask your HR team to add seats.', o.name using errcode = 'P0001';
  end if;
  -- Moving company: the old cover ends now.
  update public.organization_members
     set status = 'removed', removed_at = now(), sponsorship_ends_at = now()
   where user_id = p_user and status = 'active';
  insert into public.organization_members (org_id, user_id, work_email, joined_via)
  values (p_org, p_user, p_email, p_via);
end;
$$;

-- Step 1. p_slug (invite link) or p_code, and/or p_work_email.
-- Returns {status: 'joined' | 'code_sent', name, email?}.
create or replace function public.org_join_start(
  p_slug text default null, p_code text default null, p_work_email text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_account text := lower(public.current_user_email());
  v_confirmed boolean;
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_email text := public.org_clean_email(p_work_email);
  v_domain text;
  o public.organizations;
  v_via text;
  v_otp text;
  v_prev public.organization_email_codes;
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select email_confirmed_at is not null into v_confirmed from auth.users where id = v_uid;

  if length(v_code) = 8 then
    select * into o from public.organizations
     where join_code = left(v_code, 4) || '-' || right(v_code, 4) and join_code_enabled;
    if o.id is null then
      raise exception 'That code doesn''t match a company. Check it with your HR team.' using errcode = 'P0001';
    end if;
  elsif nullif(trim(p_slug), '') is not null then
    select * into o from public.organizations where slug = lower(trim(p_slug));
  end if;

  if v_email is null and o.id is null then
    v_email := v_account;
  end if;
  v_domain := split_part(v_email, '@', 2);

  -- No company yet: find it from the email.
  if o.id is null and v_email is not null then
    select oo.* into o from public.organizations oo
     where exists (select 1 from public.organization_eligibility e where e.org_id = oo.id and e.email = v_email)
     order by oo.created_at limit 1;
    if o.id is null then
      select oo.* into o from public.organization_domains d
      join public.organizations oo on oo.id = d.org_id
      where d.domain = v_domain and oo.domain_join_enabled;
    end if;
  end if;
  if o.id is null then
    raise exception 'We couldn''t find a company for that. Use the link or code from your HR team, or your work email.' using errcode = 'P0001';
  end if;
  if o.status not in ('trial', 'active', 'past_due') then
    raise exception '%''s plan isn''t active right now. Please ask your HR team.', o.name using errcode = 'P0001';
  end if;

  -- How do they get in?
  if length(v_code) = 8 and not o.eligibility_required then
    perform public.org_add_member(o.id, v_uid, null, 'code');
    return jsonb_build_object('status', 'joined', 'name', o.name);
  end if;

  if v_email is null then
    return jsonb_build_object('status', 'need_email', 'name', o.name,
      'domains', (select coalesce(jsonb_agg(d.domain), '[]') from public.organization_domains d
                  where d.org_id = o.id and o.domain_join_enabled));
  end if;

  if exists (select 1 from public.organization_eligibility e where e.org_id = o.id and e.email = v_email) then
    v_via := 'list';
  elsif not o.eligibility_required and o.domain_join_enabled
        and exists (select 1 from public.organization_domains d where d.org_id = o.id and d.domain = v_domain) then
    v_via := 'domain';
  else
    raise exception '% isn''t on %''s list. Check the address, or ask your HR team to add you.', v_email, o.name
      using errcode = 'P0001';
  end if;

  -- Their own confirmed sign-in email needs no code.
  if v_email = v_account and v_confirmed then
    perform public.org_add_member(o.id, v_uid, v_email, v_via);
    return jsonb_build_object('status', 'joined', 'name', o.name);
  end if;

  select * into v_prev from public.organization_email_codes where user_id = v_uid;
  if v_prev.user_id is not null and v_prev.created_at > now() - interval '1 hour' and v_prev.sent_count >= 5 then
    raise exception 'We''ve sent several codes already. Please wait an hour and try again.' using errcode = 'P0001';
  end if;

  v_otp := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');
  insert into public.organization_email_codes (user_id, org_id, email, joined_via, code_hash, expires_at)
  values (v_uid, o.id, v_email, v_via, encode(extensions.digest(v_otp || v_uid::text, 'sha256'), 'hex'),
          now() + interval '15 minutes')
  on conflict (user_id) do update
    set org_id = excluded.org_id, email = excluded.email, joined_via = excluded.joined_via,
        code_hash = excluded.code_hash, attempts = 0, expires_at = excluded.expires_at,
        sent_count = case when public.organization_email_codes.created_at > now() - interval '1 hour'
                          then public.organization_email_codes.sent_count + 1 else 1 end,
        created_at = case when public.organization_email_codes.created_at > now() - interval '1 hour'
                          then public.organization_email_codes.created_at else now() end;

  perform public.org_send_email(v_email, v_otp || ' is your MindPillars code',
    'Your code: ' || v_otp,
    'Enter it on the MindPillars page to confirm you work at ' || o.name || '. It works for 15 minutes.',
    null, null, 'If you didn''t ask for this, you can ignore this email.',
    'org-otp/' || v_uid || '/' || extract(epoch from now())::bigint);

  return jsonb_build_object('status', 'code_sent', 'name', o.name, 'email', v_email);
end;
$$;

-- Step 2, after code_sent. Returns {status: 'joined', name}, or
-- {status: 'wrong_code', message, attempts_left} for a wrong code (five
-- tries per code). Expired / too many tries / plan not active raise.
create or replace function public.org_join_confirm(p_code text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  c public.organization_email_codes;
  o public.organizations;
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select * into c from public.organization_email_codes where user_id = v_uid for update;
  if c.user_id is null or c.expires_at < now() then
    raise exception 'That code has expired. Ask for a new one.' using errcode = 'P0001';
  end if;
  if c.attempts >= 5 then
    raise exception 'Too many tries. Ask for a new code.' using errcode = 'P0001';
  end if;
  if c.code_hash <> encode(extensions.digest(regexp_replace(coalesce(p_code, ''), '\D', '', 'g') || v_uid::text, 'sha256'), 'hex') then
    -- Returned, not raised: an exception would roll the count back and
    -- give unlimited guesses.
    update public.organization_email_codes set attempts = attempts + 1 where user_id = v_uid;
    return jsonb_build_object('status', 'wrong_code',
      'message', 'That code isn''t right. Check the email and try again.',
      'attempts_left', greatest(0, 4 - c.attempts));
  end if;
  delete from public.organization_email_codes where user_id = v_uid;
  -- Things may have changed in the 15 minutes since the code was sent.
  select * into o from public.organizations where id = c.org_id;
  if o.status not in ('trial', 'active', 'past_due') then
    raise exception '%''s plan isn''t active right now. Please ask your HR team.', o.name using errcode = 'P0001';
  end if;
  if (c.joined_via = 'list' or o.eligibility_required)
     and not exists (select 1 from public.organization_eligibility e where e.org_id = o.id and e.email = c.email) then
    raise exception '% isn''t on %''s list. Check the address, or ask your HR team to add you.', c.email, o.name
      using errcode = 'P0001';
  end if;
  perform public.org_add_member(c.org_id, v_uid, c.email, c.joined_via);
  return jsonb_build_object('status', 'joined', 'name', o.name);
end;
$$;

-- After "Sign in with SSO": the account's email is the work email.
create or replace function public.org_join_sso()
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(public.current_user_email());
  o public.organizations;
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if not exists (select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) e
                 where e ->> 'method' like 'sso%') then
    raise exception 'Sign in with your company''s single sign-on first.' using errcode = '42501';
  end if;
  select oo.* into o from public.organization_domains d
  join public.organizations oo on oo.id = d.org_id
  where d.domain = split_part(v_email, '@', 2) and oo.sso_enabled;
  if o.id is null then
    raise exception 'Your company hasn''t set up single sign-on with us yet.' using errcode = 'P0001';
  end if;
  if o.status not in ('trial', 'active', 'past_due') then
    raise exception '%''s plan isn''t active right now. Please ask your HR team.', o.name using errcode = 'P0001';
  end if;
  if o.eligibility_required and not exists (
       select 1 from public.organization_eligibility e where e.org_id = o.id and e.email = v_email) then
    raise exception '% isn''t on %''s list. Please ask your HR team to add you.', v_email, o.name using errcode = 'P0001';
  end if;
  perform public.org_add_member(o.id, v_uid, v_email, 'sso');
  return jsonb_build_object('status', 'joined', 'name', o.name);
end;
$$;

create or replace function public.org_my_benefit()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  m public.organization_members;
  o public.organizations;
  v_used integer;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select mm.* into m from public.organization_members mm
  where mm.user_id = auth.uid() and public.org_member_current(mm)
  order by (mm.status = 'active') desc, mm.joined_at desc limit 1;
  if m.id is null then
    return null;
  end if;
  select * into o from public.organizations where id = m.org_id;
  select count(*) into v_used from public.therapy_requests r
  where r.user_id = auth.uid() and r.sponsor_org_id = o.id and not r.sponsor_overage
    and r.status <> 'cancelled' and r.created_at >= public.org_period_start(o);
  return jsonb_build_object(
    'company', o.name,
    'status', o.status,
    'membership', m.status,
    'joined_at', m.joined_at,
    'cover_ends_at', m.sponsorship_ends_at,
    'premium', o.status in ('trial', 'active', 'past_due'),
    'sessions_covered', o.status in ('active', 'past_due'),
    'sessions_per_year', o.sessions_per_year,
    'sessions_used', v_used,
    'sessions_left', greatest(0, o.sessions_per_year - v_used),
    'extra_sessions_covered', o.overage_enabled,
    'renews_on', public.org_period_start(o) + interval '1 year');
end;
$$;

create or replace function public.org_leave()
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  update public.organization_members
     set status = 'removed', removed_at = now(), sponsorship_ends_at = now()
   where user_id = auth.uid() and status = 'active';
  update public.organization_members
     set sponsorship_ends_at = now()
   where user_id = auth.uid() and status = 'removed' and sponsorship_ends_at > now();
end;
$$;

-- ── 9. HR: create a company, see it, run it ──────────────────────────

-- Self-serve sign-up: up to 100 employees, 5–100 seats, 14-day trial.
create or replace function public.org_create(
  p_name text, p_country text, p_employee_count integer, p_seats integer,
  p_interval text default 'month', p_use_domain boolean default true)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(public.current_user_email());
  v_domain text;
  v_price jsonb;
  v_id uuid;
  v_slug text;
  v_code text;
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users where id = v_uid and email_confirmed_at is not null) then
    raise exception 'Confirm your email first.' using errcode = 'P0001';
  end if;
  if coalesce(p_employee_count, 0) > 100 then
    raise exception 'For teams over 100 people, book a demo and we''ll set you up.' using errcode = 'P0001';
  end if;
  if coalesce(p_seats, 0) < 5 or p_seats > 100 then
    raise exception 'Choose between 5 and 100 seats.' using errcode = 'P0001';
  end if;
  if p_interval is null or p_interval not in ('month', 'year') then
    raise exception 'Choose monthly or yearly billing.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_name), '') is null or length(trim(p_name)) > 120 then
    raise exception 'Add your company''s name.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.organization_admins where user_id = v_uid and role = 'owner') >= 3 then
    raise exception 'You already run three companies here. Contact us to add more.' using errcode = 'P0001';
  end if;

  v_price := public.org_price_for(p_country);
  loop
    v_slug := public.org_slug_for(p_name);
    exit when not exists (select 1 from public.organizations where slug = v_slug);
  end loop;
  loop
    v_code := public.org_new_code();
    exit when not exists (select 1 from public.organizations where join_code = v_code);
  end loop;

  v_domain := split_part(v_email, '@', 2);
  insert into public.organizations (
    name, slug, country_code, employee_count, plan, status, trial_ends_at, seats,
    currency, pepm_minor, billing_interval, sessions_per_year, join_code,
    domain_join_enabled, created_by)
  values (
    trim(p_name), v_slug, public.country_code_of(p_country), p_employee_count, 'self_serve', 'trial',
    now() + interval '14 days', p_seats, 'USD', (v_price ->> 'pepm_minor')::int, p_interval,
    (v_price ->> 'sessions_per_year')::int, v_code,
    p_use_domain and not public.org_public_email_domain(v_domain)
      and not exists (select 1 from public.organization_domains where domain = v_domain),
    v_uid)
  returning id into v_id;

  if p_use_domain and not public.org_public_email_domain(v_domain)
     and not exists (select 1 from public.organization_domains where domain = v_domain) then
    insert into public.organization_domains (domain, org_id, added_by) values (v_domain, v_id, v_email);
  end if;
  insert into public.organization_admins (org_id, email, user_id, role, invited_by)
  values (v_id, v_email, v_uid, 'owner', v_email);

  perform public.send_app_email(public.care_team_email(), v_email,
    'New company sign-up: ' || trim(p_name),
    public.email_layout('New company sign-up', 'New company sign-up', public.email_escape(trim(p_name)),
      public.email_row('Owner', public.email_escape(v_email))
      || public.email_row('Seats', p_seats::text)
      || public.email_row('Billing', p_interval),
      'Trial ends in 14 days.'),
    'New company ' || trim(p_name) || ' by ' || v_email, 'org-new/' || v_id);

  return jsonb_build_object('id', v_id, 'slug', v_slug);
end;
$$;

-- Companies the signed-in person runs. Also claims HR invites sent to
-- their (confirmed) email.
create or replace function public.org_my()
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(public.current_user_email());
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if exists (select 1 from auth.users where id = v_uid and email_confirmed_at is not null) then
    update public.organization_admins set user_id = v_uid
     where email = v_email and user_id is null;
  end if;
  return jsonb_build_object(
    'orgs', (select coalesce(jsonb_agg(jsonb_build_object(
                'id', o.id, 'name', o.name, 'status', o.status, 'role', a.role) order by o.name), '[]')
             from public.organization_admins a join public.organizations o on o.id = a.org_id
             where a.user_id = v_uid),
    'benefit', public.org_my_benefit());
end;
$$;

-- The HR dashboard.
create or replace function public.org_overview(p_org uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  o public.organizations;
  v_start timestamptz;
  v_joined integer;
  v_people integer;
  v_sessions integer;
  v_completed integer;
  v_overage integer;
  v_ratings integer;
  v_rating numeric;
  k constant integer := 10;
begin
  perform public.org_require_admin(p_org);
  select * into o from public.organizations where id = p_org;
  v_start := public.org_period_start(o);
  select count(*) into v_joined from public.organization_members where org_id = p_org and status = 'active';

  select count(distinct r.user_id), count(*), count(*) filter (where r.status = 'completed'),
         count(*) filter (where r.sponsor_overage)
    into v_people, v_sessions, v_completed, v_overage
  from public.therapy_requests r
  where r.sponsor_org_id = p_org and r.status <> 'cancelled' and r.created_at >= v_start;

  select count(*), avg(t.rating) into v_ratings, v_rating
  from public.therapy_ratings t join public.therapy_requests r on r.id = t.request_id
  where r.sponsor_org_id = p_org and t.author_role = 'client' and r.created_at >= v_start;

  return jsonb_build_object(
    'org', jsonb_build_object(
      'id', o.id, 'name', o.name, 'slug', o.slug, 'plan', o.plan, 'status', o.status,
      'trial_ends_at', o.trial_ends_at, 'started_at', o.started_at, 'seats', o.seats,
      'currency', o.currency, 'pepm_minor', o.pepm_minor,
      'pepm_label', public.org_label(o.pepm_minor, o.currency),
      'billing_interval', o.billing_interval, 'annual_discount', o.annual_discount,
      'sessions_per_year', o.sessions_per_year, 'overage_enabled', o.overage_enabled,
      'join_code', o.join_code, 'join_code_enabled', o.join_code_enabled,
      'domain_join_enabled', o.domain_join_enabled, 'eligibility_required', o.eligibility_required,
      'sso_enabled', o.sso_enabled, 'country_code', o.country_code,
      'billing_linked', o.stripe_subscription_id is not null,
      'current_period_end', o.current_period_end,
      'invite_link', public.org_site_url() || '/join/' || o.slug,
      'domains', (select coalesce(jsonb_agg(d.domain order by d.domain), '[]') from public.organization_domains d where d.org_id = o.id),
      'list_size', (select count(*) from public.organization_eligibility e where e.org_id = o.id),
      'session_price', public.org_price_for(o.country_code) -> 'session_price'),
    'my_role', (select a.role from public.organization_admins a where a.org_id = p_org and a.user_id = auth.uid()),
    'privacy_threshold', k,
    'joined', v_joined,
    'period_start', v_start,
    'period_end', v_start + interval '1 year',
    -- Usage only when at least k people are behind each number.
    'usage', case when v_joined >= k then jsonb_build_object(
        'people_in_therapy', case when v_people >= k then v_people end,
        'sessions', case when v_people >= k then v_sessions end,
        'sessions_completed', case when v_people >= k then v_completed end,
        'bundle_total', v_joined * o.sessions_per_year,
        'avg_rating', case when v_ratings >= k then round(v_rating, 1) end)
      end,
    -- Billing needs this number whatever the size; it never says who.
    'extra_sessions_billable', case when o.overage_enabled then v_overage else 0 end);
end;
$$;

create or replace function public.org_update(p_org uuid, p_patch jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code text;
begin
  perform public.org_require_admin(p_org);
  if p_patch ? 'name' and length(trim(p_patch ->> 'name')) not between 2 and 120 then
    raise exception 'Company names are 2 to 120 characters.' using errcode = 'P0001';
  end if;
  if coalesce((p_patch ->> 'regenerate_code')::boolean, false) then
    loop
      v_code := public.org_new_code();
      exit when not exists (select 1 from public.organizations where join_code = v_code);
    end loop;
  end if;
  update public.organizations set
    name = coalesce(trim(p_patch ->> 'name'), name),
    overage_enabled = coalesce((p_patch ->> 'overage_enabled')::boolean, overage_enabled),
    join_code_enabled = coalesce((p_patch ->> 'join_code_enabled')::boolean, join_code_enabled),
    domain_join_enabled = coalesce((p_patch ->> 'domain_join_enabled')::boolean, domain_join_enabled),
    eligibility_required = coalesce((p_patch ->> 'eligibility_required')::boolean, eligibility_required),
    country_code = coalesce(public.country_code_of(p_patch ->> 'country_code'), country_code),
    join_code = coalesce(v_code, join_code)
  where id = p_org;
  return public.org_overview(p_org);
end;
$$;

-- Seats can be changed here only while no Stripe subscription runs it;
-- otherwise the org-billing Edge Function changes Stripe and then the row.
create or replace function public.org_set_seats(p_org uuid, p_seats integer)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations;
begin
  perform public.org_require_admin(p_org);
  select * into o from public.organizations where id = p_org for update;
  if o.stripe_subscription_id is not null and not public.is_admin() then
    raise exception 'Change seats from Billing.' using errcode = 'P0001';
  end if;
  if o.plan = 'self_serve' and not public.is_admin() and (p_seats < 5 or p_seats > 100) then
    raise exception 'Choose between 5 and 100 seats. For more, contact us.' using errcode = 'P0001';
  end if;
  if p_seats < (select count(*) from public.organization_members where org_id = p_org and status = 'active') then
    raise exception 'More people have joined than that. Remove people first, or keep more seats.' using errcode = 'P0001';
  end if;
  update public.organizations set seats = p_seats where id = p_org;
  return public.org_overview(p_org);
end;
$$;

create or replace function public.org_add_domain(p_org uuid, p_domain text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_domain text := lower(trim(both '@ ' from coalesce(p_domain, '')));
begin
  perform public.org_require_admin(p_org);
  if v_domain !~ '^[a-z0-9.-]+\.[a-z]{2,}$' then
    raise exception 'That doesn''t look like a domain (e.g. acme.com).' using errcode = 'P0001';
  end if;
  if public.org_public_email_domain(v_domain) then
    raise exception '% is a personal email provider. Use your company''s own domain, or an eligibility list.', v_domain using errcode = 'P0001';
  end if;
  -- Proof of control: the HR person's own email is on it (the care team can add any).
  if not public.is_admin() and split_part(lower(public.current_user_email()), '@', 2) <> v_domain then
    raise exception 'You can add % once you sign in with an @% email — or contact us and we''ll add it.', v_domain, v_domain using errcode = 'P0001';
  end if;
  if exists (select 1 from public.organization_domains where domain = v_domain and org_id <> p_org) then
    raise exception '% belongs to another company here. Contact us if that''s wrong.', v_domain using errcode = 'P0001';
  end if;
  insert into public.organization_domains (domain, org_id, added_by)
  values (v_domain, p_org, lower(public.current_user_email()))
  on conflict (domain) do nothing;
  return public.org_overview(p_org);
end;
$$;

create or replace function public.org_remove_domain(p_org uuid, p_domain text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.org_require_admin(p_org);
  delete from public.organization_domains where org_id = p_org and domain = lower(trim(p_domain));
  return public.org_overview(p_org);
end;
$$;

-- Ends cover (with 30 days' grace) for whoever joined with these emails.
create or replace function public.org_end_members(p_org uuid, p_emails text[])
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.organization_members m
     set status = 'removed', removed_at = now(), sponsorship_ends_at = now() + interval '30 days'
   where m.org_id = p_org and m.status = 'active'
     and (m.work_email = any (p_emails)
          or exists (select 1 from auth.users u where u.id = m.user_id and lower(u.email) = any (p_emails)));
end;
$$;

-- Add and/or remove emails on the eligibility list; optionally email the
-- added ones an invite. Removing someone ends their cover after 30 days.
create or replace function public.org_eligibility_update(
  p_org uuid, p_add text[] default '{}', p_remove text[] default '{}', p_send_invites boolean default true)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations;
  v_add text[];
  v_remove text[];
  v_bad integer;
  v_new text[];
  e text;
begin
  perform public.org_require_admin(p_org);
  select * into o from public.organizations where id = p_org;
  if coalesce(array_length(p_add, 1), 0) + coalesce(array_length(p_remove, 1), 0) > 5000 then
    raise exception 'Up to 5,000 emails at a time, please.' using errcode = 'P0001';
  end if;
  select coalesce(array_agg(distinct x) filter (where x is not null), '{}'),
         count(*) filter (where x is null and nullif(trim(raw), '') is not null)
    into v_add, v_bad
  from (select raw, public.org_clean_email(raw) x from unnest(coalesce(p_add, '{}')) raw) s;
  select coalesce(array_agg(distinct public.org_clean_email(raw)) filter (where public.org_clean_email(raw) is not null), '{}')
    into v_remove from unnest(coalesce(p_remove, '{}')) raw;

  with ins as (
    insert into public.organization_eligibility (org_id, email)
    select p_org, x from unnest(v_add) x
    on conflict do nothing
    returning email)
  select coalesce(array_agg(email), '{}') into v_new from ins;

  delete from public.organization_eligibility where org_id = p_org and email = any (v_remove);
  perform public.org_end_members(p_org, v_remove);

  if p_send_invites and o.status in ('trial', 'active', 'past_due') then
    foreach e in array v_new loop
      perform public.org_send_email(e, o.name || ' gives you MindPillars',
        o.name || ' has you covered',
        'Your employer pays for MindPillars: premium in the app' ||
          case when o.sessions_per_year > 0 then ' and ' || o.sessions_per_year || ' therapy sessions a year' else '' end ||
          '. It''s private — ' || o.name || ' never sees what you use.',
        'Activate in 1 minute', public.org_site_url() || '/join/' || o.slug || '?email=' || replace(e, '+', '%2B'),
        'Use this email address (' || e || ') when you activate.',
        'org-invite/' || p_org || '/' || e);
    end loop;
  end if;

  return jsonb_build_object('added', coalesce(array_length(v_new, 1), 0),
                            'removed', coalesce(array_length(v_remove, 1), 0),
                            'invalid', v_bad,
                            'list_size', (select count(*) from public.organization_eligibility where org_id = p_org));
end;
$$;

create or replace function public.org_eligibility_list(
  p_org uuid, p_search text default null, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.org_require_admin(p_org);
  return jsonb_build_object(
    'total', (select count(*) from public.organization_eligibility e where e.org_id = p_org
              and (p_search is null or e.email like '%' || lower(p_search) || '%')),
    'emails', (select coalesce(jsonb_agg(jsonb_build_object('email', x.email, 'added_at', x.added_at)), '[]') from (
                 select e.email, e.added_at from public.organization_eligibility e
                 where e.org_id = p_org and (p_search is null or e.email like '%' || lower(p_search) || '%')
                 order by e.email limit least(greatest(p_limit, 1), 500) offset greatest(p_offset, 0)) x));
end;
$$;

-- Invite people without putting them on a list (domain/code companies).
create or replace function public.org_send_invites(p_org uuid, p_emails text[])
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations;
  e text;
  n integer := 0;
begin
  perform public.org_require_admin(p_org);
  select * into o from public.organizations where id = p_org;
  if o.status not in ('trial', 'active', 'past_due') then
    raise exception 'Your plan isn''t active, so invites would not work yet.' using errcode = 'P0001';
  end if;
  if coalesce(array_length(p_emails, 1), 0) > 1000 then
    raise exception 'Up to 1,000 invites at a time, please.' using errcode = 'P0001';
  end if;
  for e in select distinct public.org_clean_email(x) from unnest(p_emails) x where public.org_clean_email(x) is not null loop
    perform public.org_send_email(e, o.name || ' gives you MindPillars',
      o.name || ' has you covered',
      'Your employer pays for MindPillars: premium in the app' ||
        case when o.sessions_per_year > 0 then ' and ' || o.sessions_per_year || ' therapy sessions a year' else '' end ||
        '. It''s private — ' || o.name || ' never sees what you use.',
      'Activate in 1 minute', public.org_site_url() || '/join/' || o.slug
        || case when o.join_code_enabled and not o.eligibility_required then '?code=' || replace(o.join_code, '-', '') else '?email=' || replace(e, '+', '%2B') end,
      null, 'org-invite/' || p_org || '/' || e || '/' || current_date);
    n := n + 1;
  end loop;
  return jsonb_build_object('sent', n);
end;
$$;

-- Someone left: take them off the list and end their cover (30 days' grace).
-- Says nothing about whether they had joined.
create or replace function public.org_remove_person(p_org uuid, p_email text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := public.org_clean_email(p_email);
begin
  perform public.org_require_admin(p_org);
  if v_email is null then
    raise exception 'Enter their email address.' using errcode = 'P0001';
  end if;
  delete from public.organization_eligibility where org_id = p_org and email = v_email;
  perform public.org_end_members(p_org, array[v_email]);
end;
$$;

create or replace function public.org_admins_list(p_org uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.org_require_admin(p_org);
  return (select coalesce(jsonb_agg(jsonb_build_object('email', a.email, 'role', a.role,
                    'accepted', a.user_id is not null, 'you', a.user_id = auth.uid()) order by a.role desc, a.email), '[]')
          from public.organization_admins a where a.org_id = p_org);
end;
$$;

create or replace function public.org_admin_add(p_org uuid, p_email text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := public.org_clean_email(p_email);
  v_name text;
begin
  perform public.org_require_admin(p_org);
  if v_email is null then
    raise exception 'Enter a valid email.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.organization_admins where org_id = p_org) >= 20 then
    raise exception 'Up to 20 HR admins per company.' using errcode = 'P0001';
  end if;
  insert into public.organization_admins (org_id, email, user_id, role, invited_by)
  values (p_org, v_email,
          (select u.id from auth.users u where lower(u.email) = v_email and u.email_confirmed_at is not null limit 1),
          'admin', lower(public.current_user_email()))
  on conflict (org_id, email) do nothing;
  select name into v_name from public.organizations where id = p_org;
  perform public.org_send_email(v_email, 'You''re an admin for ' || v_name || ' on MindPillars',
    'Help run ' || v_name || '''s MindPillars plan',
    lower(public.current_user_email()) || ' added you as an HR admin. Sign in with this email to manage seats, invites and billing.',
    'Open the HR portal', public.org_site_url() || '/portal', null, 'org-admin/' || p_org || '/' || v_email);
  return public.org_admins_list(p_org);
end;
$$;

create or replace function public.org_admin_remove(p_org uuid, p_email text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.org_require_admin(p_org);
  if (select role from public.organization_admins where org_id = p_org and email = lower(trim(p_email))) = 'owner'
     and not public.is_admin() then
    raise exception 'The owner can''t be removed here. Contact us to change the owner.' using errcode = 'P0001';
  end if;
  delete from public.organization_admins where org_id = p_org and email = lower(trim(p_email));
  return public.org_admins_list(p_org);
end;
$$;

-- ── 10. Billing (Edge Functions, service role only) ─────────────────

-- Called by stripe-webhook / org-billing with the service role. Safe to
-- call again with the same event (it only sets values). An event about a
-- subscription that isn't the company's current one (a late webhook for
-- one that was replaced) only updates a still-unlinked company, so it
-- can't end a newer subscription.
create or replace function public.org_billing_apply(
  p_org uuid, p_customer text default null, p_subscription text default null,
  p_stripe_status text default null, p_seats integer default null,
  p_interval text default null, p_period_end timestamptz default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations;
  v_ended boolean := p_stripe_status in ('canceled', 'incomplete_expired');
begin
  select * into o from public.organizations where id = p_org for update;
  if not found then
    return;
  end if;
  if p_subscription is not null and o.stripe_subscription_id is not null
     and p_subscription <> o.stripe_subscription_id then
    if v_ended or p_stripe_status is null then
      -- About an old subscription: only the customer is worth keeping.
      update public.organizations set stripe_customer_id = coalesce(stripe_customer_id, p_customer)
       where id = p_org;
      return;
    end if;
    -- Otherwise a new live subscription replaces the old one (below).
  end if;
  update public.organizations set
    stripe_customer_id = coalesce(p_customer, stripe_customer_id),
    stripe_subscription_id = case when v_ended then null
                                  else coalesce(p_subscription, stripe_subscription_id) end,
    seats = case when p_seats between 1 and 1000000 then p_seats else seats end,
    billing_interval = case when p_interval in ('month', 'year') then p_interval else billing_interval end,
    current_period_end = coalesce(p_period_end, current_period_end),
    status = case
      when p_stripe_status is null then status
      when p_stripe_status = 'trialing' then 'trial'
      when p_stripe_status = 'active' then 'active'
      when p_stripe_status in ('past_due', 'unpaid') then 'past_due'
      when v_ended then 'ended'
      when p_stripe_status = 'paused' then 'paused'
      else status end,
    trial_ends_at = case when p_stripe_status = 'trialing' then coalesce(p_period_end, trial_ends_at) else trial_ends_at end
  where id = p_org;
end;
$$;

-- What the org-billing function needs to build a checkout.
create or replace function public.org_billing_info(p_org uuid)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', o.id, 'name', o.name, 'plan', o.plan, 'status', o.status, 'seats', o.seats,
    'currency', o.currency, 'pepm_minor', o.pepm_minor, 'billing_interval', o.billing_interval,
    'annual_discount', o.annual_discount, 'trial_ends_at', o.trial_ends_at,
    'stripe_customer_id', o.stripe_customer_id, 'stripe_subscription_id', o.stripe_subscription_id,
    'owner_email', (select a.email from public.organization_admins a where a.org_id = o.id and a.role = 'owner' limit 1),
    'joined', (select count(*) from public.organization_members m where m.org_id = o.id and m.status = 'active'))
  from public.organizations o where o.id = p_org;
$$;

-- ── 11. Care team (admin page) ───────────────────────────────────────

create or replace function public.admin_orgs_list()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'id', o.id, 'name', o.name, 'slug', o.slug, 'plan', o.plan, 'status', o.status,
      'country_code', o.country_code, 'seats', o.seats,
      'joined', (select count(*) from public.organization_members m where m.org_id = o.id and m.status = 'active'),
      'pepm_minor', o.pepm_minor, 'currency', o.currency, 'billing_interval', o.billing_interval,
      'sessions_per_year', o.sessions_per_year, 'overage_enabled', o.overage_enabled,
      'trial_ends_at', o.trial_ends_at, 'started_at', o.started_at,
      'owner', (select a.email from public.organization_admins a where a.org_id = o.id and a.role = 'owner' limit 1),
      'billing_linked', o.stripe_subscription_id is not null,
      'sessions_this_period', (select count(*) from public.therapy_requests r where r.sponsor_org_id = o.id
                               and r.status <> 'cancelled' and r.created_at >= public.org_period_start(o)),
      'extra_sessions', (select count(*) from public.therapy_requests r where r.sponsor_org_id = o.id
                         and r.sponsor_overage and r.status <> 'cancelled' and r.created_at >= public.org_period_start(o)),
      'created_at', o.created_at) order by o.created_at desc), '[]')
    from public.organizations o);
end;
$$;

create or replace function public.admin_org_get(p_org uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  o public.organizations;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  select * into o from public.organizations where id = p_org;
  return to_jsonb(o)
    || jsonb_build_object(
      'domains', (select coalesce(jsonb_agg(d.domain order by d.domain), '[]') from public.organization_domains d where d.org_id = o.id),
      'admins', (select coalesce(jsonb_agg(jsonb_build_object('email', a.email, 'role', a.role, 'accepted', a.user_id is not null)), '[]')
                 from public.organization_admins a where a.org_id = o.id),
      'joined', (select count(*) from public.organization_members m where m.org_id = o.id and m.status = 'active'),
      'in_grace', (select count(*) from public.organization_members m where m.org_id = o.id and m.status = 'removed'
                   and m.sponsorship_ends_at > now()),
      'list_size', (select count(*) from public.organization_eligibility e where e.org_id = o.id),
      'invite_link', public.org_site_url() || '/join/' || o.slug);
end;
$$;

-- Create (no id) or update a company. Keys left out stay as they are;
-- country_code / employee_count / trial_ends_at / started_at / notes /
-- sso_provider_id present as null (or '') clear the value.
-- domains (array) replaces the list; owner_email adds an owner invite.
create or replace function public.admin_org_save(p_org jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_country text;
  v_price jsonb;
  v_owner text := public.org_clean_email(p_org ->> 'owner_email');
  v_code text;
  v_slug text;
  v_domains text[];
  v_trial timestamptz;
  v_started timestamptz;
  v_seats integer;
  v_joined integer := 0;
  d text;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if jsonb_typeof(p_org) is distinct from 'object' then
    raise exception 'Nothing to save.' using errcode = 'P0001';
  end if;

  -- ── Check everything first, with messages the admin page can show ──
  begin
    v_id := nullif(trim(p_org ->> 'id'), '')::uuid;
  exception when others then
    raise exception 'That company id isn''t valid.' using errcode = 'P0001';
  end;
  if v_id is not null and not exists (select 1 from public.organizations where id = v_id) then
    raise exception 'That company doesn''t exist.' using errcode = 'P0001';
  end if;
  if v_id is null and nullif(trim(p_org ->> 'name'), '') is null then
    raise exception 'Name the company.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'name'), '') is not null and length(trim(p_org ->> 'name')) not between 2 and 120 then
    raise exception 'Company names are 2 to 120 characters.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'country_code'), '') is not null then
    v_country := public.country_code_of(p_org ->> 'country_code');
    if v_country is null then
      raise exception 'Unknown country: %.', p_org ->> 'country_code' using errcode = 'P0001';
    end if;
  end if;
  if nullif(trim(p_org ->> 'plan'), '') is not null and p_org ->> 'plan' not in ('self_serve', 'contract') then
    raise exception 'Plan is self_serve or contract.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'status'), '') is not null
     and p_org ->> 'status' not in ('trial', 'active', 'past_due', 'paused', 'ended') then
    raise exception 'Status is trial, active, past_due, paused or ended.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'billing_interval'), '') is not null and p_org ->> 'billing_interval' not in ('month', 'year') then
    raise exception 'Billing is month or year.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'currency'), '') is not null and upper(trim(p_org ->> 'currency')) !~ '^[A-Z]{3}$' then
    raise exception 'Currency is a three-letter code, like USD.' using errcode = 'P0001';
  end if;
  begin
    v_trial := nullif(trim(p_org ->> 'trial_ends_at'), '')::timestamptz;
    v_started := nullif(trim(p_org ->> 'started_at'), '')::timestamptz;
    v_seats := nullif(trim(p_org ->> 'seats'), '')::numeric::integer;
    if nullif(trim(p_org ->> 'employee_count'), '') is not null then
      perform (p_org ->> 'employee_count')::numeric::integer;
    end if;
    if nullif(trim(p_org ->> 'pepm_minor'), '') is not null then
      perform (p_org ->> 'pepm_minor')::numeric::integer;
    end if;
    if nullif(trim(p_org ->> 'sessions_per_year'), '') is not null then
      perform (p_org ->> 'sessions_per_year')::numeric::integer;
    end if;
    if nullif(trim(p_org ->> 'annual_discount'), '') is not null then
      perform (p_org ->> 'annual_discount')::numeric;
    end if;
  exception when others then
    raise exception 'A date or number isn''t valid: %', sqlerrm using errcode = 'P0001';
  end;
  if v_seats is not null and v_seats not between 1 and 1000000 then
    raise exception 'Seats are 1 to 1,000,000.' using errcode = 'P0001';
  end if;
  if v_id is not null then
    select count(*) into v_joined from public.organization_members where org_id = v_id and status = 'active';
  end if;
  if v_seats is not null and v_seats < v_joined then
    raise exception '% people have joined, so seats can''t go below that. Remove people first.', v_joined using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'employee_count'), '') is not null
     and (p_org ->> 'employee_count')::numeric::integer not between 1 and 1000000 then
    raise exception 'Employees are 1 to 1,000,000.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'pepm_minor'), '') is not null
     and (p_org ->> 'pepm_minor')::numeric::integer not between 0 and 100000000 then
    raise exception 'The price per seat isn''t valid.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'sessions_per_year'), '') is not null
     and (p_org ->> 'sessions_per_year')::numeric::integer not between 0 and 100 then
    raise exception 'Sessions a year are 0 to 100.' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'annual_discount'), '') is not null
     and (p_org ->> 'annual_discount')::numeric not between 0 and 0.9 then
    raise exception 'The yearly discount is between 0 and 0.9 (e.g. 0.15).' using errcode = 'P0001';
  end if;
  if nullif(trim(p_org ->> 'owner_email'), '') is not null and v_owner is null then
    raise exception 'The owner''s email isn''t valid.' using errcode = 'P0001';
  end if;
  if p_org ? 'notes' and length(p_org ->> 'notes') > 4000 then
    raise exception 'Notes are up to 4,000 characters.' using errcode = 'P0001';
  end if;
  if p_org ? 'domains' then
    if jsonb_typeof(p_org -> 'domains') <> 'array' then
      raise exception 'Domains are a list, e.g. ["acme.com"].' using errcode = 'P0001';
    end if;
    select coalesce(array_agg(distinct x) filter (where x <> ''), '{}') into v_domains
    from (select lower(trim(both '@ ' from coalesce(e, ''))) x
          from jsonb_array_elements_text(p_org -> 'domains') e) s;
    foreach d in array v_domains loop
      if d !~ '^[a-z0-9.-]+\.[a-z]{2,}$' then
        raise exception '% doesn''t look like a domain (e.g. acme.com).', d using errcode = 'P0001';
      end if;
      if public.org_public_email_domain(d) then
        raise exception '% is a personal email provider, so it can''t be a company domain. Use an eligibility list instead.', d
          using errcode = 'P0001';
      end if;
      if exists (select 1 from public.organization_domains where domain = d and org_id is distinct from v_id) then
        raise exception '% already belongs to another company.', d using errcode = 'P0001';
      end if;
    end loop;
  end if;

  -- ── Save ──
  if v_id is null then
    v_price := public.org_price_for(v_country);
    loop
      v_slug := public.org_slug_for(p_org ->> 'name');
      exit when not exists (select 1 from public.organizations where slug = v_slug);
    end loop;
    loop
      v_code := public.org_new_code();
      exit when not exists (select 1 from public.organizations where join_code = v_code);
    end loop;
    insert into public.organizations (name, slug, country_code, plan, status, seats, pepm_minor,
      sessions_per_year, join_code, trial_ends_at, created_by)
    values (trim(p_org ->> 'name'), v_slug, v_country, 'contract', 'active',
      coalesce(v_seats, 10), coalesce(nullif(trim(p_org ->> 'pepm_minor'), '')::numeric::int, (v_price ->> 'pepm_minor')::int),
      coalesce(nullif(trim(p_org ->> 'sessions_per_year'), '')::numeric::int, (v_price ->> 'sessions_per_year')::int),
      v_code, null, auth.uid())
    returning id into v_id;
  end if;

  update public.organizations set
    name = coalesce(nullif(trim(p_org ->> 'name'), ''), name),
    country_code = case when p_org ? 'country_code' then v_country else country_code end,
    employee_count = case when p_org ? 'employee_count'
                          then nullif(trim(p_org ->> 'employee_count'), '')::numeric::int else employee_count end,
    plan = coalesce(nullif(trim(p_org ->> 'plan'), ''), plan),
    status = coalesce(nullif(trim(p_org ->> 'status'), ''), status),
    trial_ends_at = case when p_org ? 'trial_ends_at' then v_trial else trial_ends_at end,
    started_at = case when p_org ? 'started_at' then v_started else started_at end,
    seats = coalesce(v_seats, seats),
    currency = coalesce(upper(nullif(trim(p_org ->> 'currency'), '')), currency),
    pepm_minor = coalesce(nullif(trim(p_org ->> 'pepm_minor'), '')::numeric::int, pepm_minor),
    billing_interval = coalesce(nullif(trim(p_org ->> 'billing_interval'), ''), billing_interval),
    annual_discount = coalesce(nullif(trim(p_org ->> 'annual_discount'), '')::numeric, annual_discount),
    sessions_per_year = coalesce(nullif(trim(p_org ->> 'sessions_per_year'), '')::numeric::int, sessions_per_year),
    overage_enabled = coalesce((p_org ->> 'overage_enabled')::boolean, overage_enabled),
    join_code_enabled = coalesce((p_org ->> 'join_code_enabled')::boolean, join_code_enabled),
    domain_join_enabled = coalesce((p_org ->> 'domain_join_enabled')::boolean, domain_join_enabled),
    eligibility_required = coalesce((p_org ->> 'eligibility_required')::boolean, eligibility_required),
    sso_provider_id = case when p_org ? 'sso_provider_id' then nullif(trim(p_org ->> 'sso_provider_id'), '') else sso_provider_id end,
    sso_enabled = coalesce((p_org ->> 'sso_enabled')::boolean, sso_enabled),
    notes = case when p_org ? 'notes' then nullif(trim(p_org ->> 'notes'), '') else notes end
  where id = v_id;

  if p_org ? 'domains' then
    delete from public.organization_domains where org_id = v_id and domain <> all (v_domains);
    insert into public.organization_domains (domain, org_id, added_by)
    select x, v_id, lower(public.current_user_email()) from unnest(v_domains) x
    on conflict (domain) do nothing;
  end if;

  if v_owner is not null and not exists (select 1 from public.organization_admins where org_id = v_id and email = v_owner) then
    insert into public.organization_admins (org_id, email, user_id, role, invited_by)
    values (v_id, v_owner,
            (select u.id from auth.users u where lower(u.email) = v_owner and u.email_confirmed_at is not null limit 1),
            case when exists (select 1 from public.organization_admins where org_id = v_id and role = 'owner') then 'admin' else 'owner' end,
            lower(public.current_user_email()));
    perform public.org_send_email(v_owner, 'Your MindPillars for Work account is ready',
      (select name from public.organizations where id = v_id) || ' is set up',
      'Sign in with this email to invite your team, see how the plan is used, and manage billing.',
      'Open the HR portal', public.org_site_url() || '/portal', null, 'org-owner/' || v_id || '/' || v_owner);
  end if;

  if nullif(trim(p_org ->> 'lead_id'), '') is not null then
    update public.organization_leads set org_id = v_id, status = 'won', updated_at = now()
     where id = (p_org ->> 'lead_id')::uuid;
  end if;

  return public.admin_org_get(v_id);
end;
$$;

create or replace function public.admin_org_leads()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(l) || jsonb_build_object(
            'country_name', (select c.name from public.countries c where c.code = l.country_code))
          order by l.created_at desc), '[]')
          from public.organization_leads l);
end;
$$;

create or replace function public.admin_org_lead_update(p_id uuid, p_status text, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  update public.organization_leads
     set status = coalesce(p_status, status),
         admin_note = case when p_note is null then admin_note else nullif(trim(p_note), '') end,
         updated_at = now()
   where id = p_id;
end;
$$;

create or replace function public.admin_org_prices()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(p) order by p.country_code), '[]') from public.organization_prices p);
end;
$$;

-- p_pepm_minor null deletes the country's own price (the base can't be deleted).
create or replace function public.admin_org_price_set(p_country text, p_pepm_minor integer, p_sessions integer default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := case when p_country = '*' then '*' else public.country_code_of(p_country) end;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if v_code is null then
    raise exception 'Unknown country.' using errcode = 'P0001';
  end if;
  if p_pepm_minor is null then
    if v_code = '*' then
      raise exception 'The base price can''t be removed.' using errcode = 'P0001';
    end if;
    delete from public.organization_prices where country_code = v_code;
  else
    insert into public.organization_prices (country_code, pepm_minor, sessions_per_year, updated_by, updated_at)
    values (v_code, p_pepm_minor, p_sessions, lower(public.current_user_email()), now())
    on conflict (country_code) do update set pepm_minor = excluded.pepm_minor,
      sessions_per_year = excluded.sessions_per_year, updated_by = excluded.updated_by, updated_at = now();
  end if;
  return public.admin_org_prices();
end;
$$;

-- ── 12. Schedule ─────────────────────────────────────────────────────

select cron.unschedule('org-housekeeping')
 where exists (select 1 from cron.job where jobname = 'org-housekeeping');
select cron.schedule('org-housekeeping', '17 * * * *', $$select public.org_housekeeping()$$);

-- ── 13. Who can call what ────────────────────────────────────────────

do $$
declare
  f text;
begin
  -- Internal: nobody but definer functions / the service role.
  foreach f in array array[
    'public.org_site_url()', 'public.org_public_email_domain(text)', 'public.org_clean_email(text)',
    'public.org_new_code()', 'public.org_slug_for(text)', 'public.org_label(bigint, text)',
    'public.org_require_admin(uuid)', 'public.org_member_current(public.organization_members)',
    'public.org_period_start(public.organizations)', 'public.org_price_for(text)',
    'public.org_sync_user(uuid)', 'public.organization_members_sync()', 'public.organizations_status_sync()',
    'public.organizations_touch()', 'public.org_housekeeping()', 'public.therapy_requests_sponsor()',
    'public.therapy_requests_sponsor_guard()',
    'public.org_sponsor_for_request(uuid)',
    'public.org_send_email(text, text, text, text, text, text, text, text)',
    'public.org_add_member(uuid, uuid, text, text)', 'public.org_end_members(uuid, text[])',
    'public.org_billing_apply(uuid, text, text, text, integer, text, timestamptz)',
    'public.org_billing_info(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;

  -- Anyone (the public site).
  foreach f in array array[
    'public.org_price_quote(text)',
    'public.org_request_demo(text, text, text, integer, text, text, text, text)',
    'public.org_join_info(text, text)', 'public.org_sso_lookup(text)'] loop
    execute format('revoke all on function %s from public', f);
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;

  -- Signed in (each checks who is calling).
  foreach f in array array[
    'public.org_is_admin(uuid)',
    'public.org_join_start(text, text, text)', 'public.org_join_confirm(text)', 'public.org_join_sso()',
    'public.org_my_benefit()', 'public.org_leave()',
    'public.org_create(text, text, integer, integer, text, boolean)', 'public.org_my()',
    'public.org_overview(uuid)', 'public.org_update(uuid, jsonb)', 'public.org_set_seats(uuid, integer)',
    'public.org_add_domain(uuid, text)', 'public.org_remove_domain(uuid, text)',
    'public.org_eligibility_update(uuid, text[], text[], boolean)',
    'public.org_eligibility_list(uuid, text, integer, integer)',
    'public.org_send_invites(uuid, text[])', 'public.org_remove_person(uuid, text)',
    'public.org_admins_list(uuid)', 'public.org_admin_add(uuid, text)', 'public.org_admin_remove(uuid, text)',
    'public.admin_orgs_list()', 'public.admin_org_get(uuid)', 'public.admin_org_save(jsonb)',
    'public.admin_org_leads()', 'public.admin_org_lead_update(uuid, text, text)',
    'public.admin_org_prices()', 'public.admin_org_price_set(text, integer, integer)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

grant execute on function public.org_billing_apply(uuid, text, text, text, integer, text, timestamptz) to service_role;
grant execute on function public.org_billing_info(uuid) to service_role;
grant execute on function public.org_is_admin(uuid) to service_role;
-- The insert trigger runs as the app user and asks this (own account only).
grant execute on function public.org_sponsor_for_request(uuid) to authenticated;
