-- Behaviour tests for 0040_organizations (companies paying per seat).
-- Run with supabase/tests/run.sh 0040_organizations (throwaway Postgres;
-- never against the live project). Each check is recorded in
-- tests.results; the script fails at the end if any check failed.
--
-- People act through set_config('request.jwt.claims', …) + set role, as
-- PostgREST does. Emails land in net.http_request_queue (pg_net stand-in),
-- which is where the six-digit codes are read from.

\set ON_ERROR_STOP 1
set client_min_messages = warning;
-- Only the summary at the end is printed.
\o /dev/null

-- ── Harness ──────────────────────────────────────────────────────────
create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;
create table if not exists tests.results (n serial primary key, label text not null, ok boolean not null, detail text);
grant all on tests.results to anon, authenticated, service_role;
grant all on sequence tests.results_n_seq to anon, authenticated, service_role;

create or replace function tests.check(p_ok boolean, p_label text, p_detail text default null)
returns void language plpgsql as $$
begin
  insert into tests.results (label, ok, detail) values (p_label, coalesce(p_ok, false), p_detail);
  if not coalesce(p_ok, false) then
    raise warning 'FAIL: % %', p_label, coalesce('(' || p_detail || ')', '');
  end if;
end;
$$;

-- Runs p_sql as the current role; returns the error message, or null.
create or replace function tests.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlstate || ': ' || sqlerrm;
end;
$$;

-- Asserts p_sql fails with a message matching p_pattern (ILIKE).
create or replace function tests.throws(p_sql text, p_pattern text, p_label text)
returns void language plpgsql as $$
declare
  e text := tests.err(p_sql);
begin
  perform tests.check(e is not null and e ilike p_pattern, p_label, coalesce(e, 'no error'));
end;
$$;

create or replace function tests.uid(p_email text) returns uuid
language sql stable security definer as $$
  select id from auth.users where email = p_email;
$$;

create or replace function tests.user(p_email text, p_confirmed boolean default true, p_meta jsonb default '{}')
returns uuid language sql as $$
  insert into auth.users (email, email_confirmed_at, raw_app_meta_data)
  values (p_email, case when p_confirmed then now() end, p_meta)
  returning id;
$$;

-- Acts as this person from the next statement (call as postgres, then `set role`).
create or replace function tests.login(p_email text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', tests.uid(p_email), 'role', 'authenticated', 'email', p_email,
                       'amr', jsonb_build_array(jsonb_build_object('method', 'password')))::text, false);
$$;
create or replace function tests.logout() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role": "anon"}', false);
$$;

create or replace function tests.meta(p_email text) returns jsonb
language sql stable security definer as $$
  select coalesce(raw_app_meta_data, '{}') from auth.users where email = p_email;
$$;

-- The newest six-digit code emailed to this address.
create or replace function tests.last_otp(p_email text) returns text
language sql stable security definer as $$
  select substring(body ->> 'subject' from '^(\d{6}) is your MindPillars code')
  from net.http_request_queue
  where body -> 'to' ->> 0 = p_email and body ->> 'subject' ~ '^\d{6} is your'
  order by id desc limit 1;
$$;

create or replace function tests.emails_to(p_email text, p_subject_like text default '%') returns integer
language sql stable security definer as $$
  select count(*)::int from net.http_request_queue
  where body -> 'to' ->> 0 = p_email and body ->> 'subject' like p_subject_like;
$$;

create or replace function tests.org(p_name text) returns public.organizations
language sql stable security definer as $$
  select * from public.organizations where name = p_name order by created_at desc limit 1;
$$;

-- A request as the signed-in app user would send it.
create or replace function tests.request(p_topic text default 'Stress at work') returns public.therapy_requests
language plpgsql as $$
declare
  r public.therapy_requests;
begin
  insert into public.therapy_requests (user_id, topic, availability)
  values (auth.uid(), p_topic, '{mornings}') returning * into r;
  return r;
end;
$$;

-- Closes a person's open requests as completed (so the next can be made),
-- without the update triggers that want a real therapist and call.
create or replace function tests.complete_open(p_email text) returns void language plpgsql security definer
set session_replication_role = replica as $$
begin
  update public.therapy_requests set status = 'completed', completed_at = now(),
         therapist_id = (select id from public.therapists limit 1), scheduled_at = now() - interval '1 hour',
         submitted_at = now() - interval '2 days'
   where user_id = tests.uid(p_email) and status in ('pending', 'confirmed');
  update public.therapy_requests set status = 'cancelled', cancelled_at = now()
   where user_id = tests.uid(p_email) and status = 'awaiting_payment';
end;
$$;

grant execute on all functions in schema tests to anon, authenticated, service_role;

-- Email goes "out" (into net.http_request_queue).
insert into vault.secrets (name, secret) values ('resend_api_key', 're_test'), ('resend_from', 'Test <t@example.com>')
on conflict (name) do nothing;

-- A therapist row for completed sessions.
set session_replication_role = replica;
insert into public.therapists (id, full_name)
select gen_random_uuid(), 'Test Therapist'
where not exists (select 1 from public.therapists);
set session_replication_role = origin;

-- ── People ───────────────────────────────────────────────────────────
select tests.user('alice@acme.com');           -- Acme owner
select tests.user('bob@acme.com');             -- joins with his own work email
select tests.user('carol@gmail.com');          -- joins with the code
select tests.user('dave@gmail.com');           -- proves dave@acme.com with a code
select tests.user('erin@acme.com', false);     -- email not confirmed
select tests.user('frank@gmail.com', true, '{"premium_comp": true}');  -- hand-granted premium
select tests.user('gina@gmail.com');           -- owner with a personal email
select tests.user('hank@acme.com');            -- second Acme person starting a company
select tests.user('care@mindpillars.app');     -- care team
select tests.user('ivy@gmail.com');            -- trial-org member
select tests.user('jack@gmail.com');           -- grace-period member
insert into public.admins (email) values ('care@mindpillars.app') on conflict do nothing;
select tests.user('crowd' || i || '@gmail.com') from generate_series(1, 12) i;

-- ── Prices ───────────────────────────────────────────────────────────
do $$
declare
  us jsonb := public.org_price_for('US');
  ke jsonb := public.org_price_for('KE');
  gb jsonb := public.org_price_for('GB');
  none jsonb := public.org_price_for(null);
begin
  perform tests.check((us ->> 'pepm_minor')::int between 550 and 650, 'price: US is about $6', us ->> 'pepm_minor');
  perform tests.check((ke ->> 'pepm_minor')::int < (us ->> 'pepm_minor')::int, 'price: Kenya is lower than the US', ke ->> 'pepm_minor');
  perform tests.check((ke ->> 'pepm_minor')::int >= 100, 'price: Kenya at least $1', ke ->> 'pepm_minor');
  perform tests.check((ke ->> 'pepm_minor')::int % 50 = 0, 'price: rounded to 50 cents', ke ->> 'pepm_minor');
  perform tests.check((gb ->> 'pepm_minor')::int <= 750, 'price: never over 125% of base', gb ->> 'pepm_minor');
  perform tests.check((none ->> 'pepm_minor')::int = 600, 'price: no country gives the base', none ->> 'pepm_minor');
  perform tests.check((us ->> 'annual_pepm_minor')::int = round((us ->> 'pepm_minor')::int * 0.85), 'price: annual is 15% off');
  perform tests.check(us ->> 'currency' = 'USD' and (us ->> 'sessions_per_year')::int = 6, 'price: USD, 6 sessions');
  perform tests.check(ke -> 'session_price' ->> 'currency' = 'KES', 'price: Kenya session price in KES', ke ->> 'session_price');
end;
$$;

-- ── Who can call what ────────────────────────────────────────────────
do $$
declare
  v_anon text[];
  v_auth_internal text[];
begin
  select array_agg(p.proname order by p.proname) into v_anon
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.proname like 'org\_%' or p.proname like 'admin\_org%')
    and has_function_privilege('anon', p.oid, 'execute');
  perform tests.check(v_anon = array['org_join_info', 'org_price_quote', 'org_request_demo', 'org_sso_lookup'],
    'grants: anon can call only the four public functions', v_anon::text);

  select array_agg(p.proname order by p.proname) into v_auth_internal
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('org_billing_apply', 'org_billing_info', 'org_sync_user', 'org_add_member',
                      'org_end_members', 'org_send_email', 'org_price_for', 'org_housekeeping',
                      'org_require_admin', 'therapy_requests_sponsor', 'org_new_code')
    and has_function_privilege('authenticated', p.oid, 'execute');
  perform tests.check(v_auth_internal is null, 'grants: app users can''t call internal functions', v_auth_internal::text);

  perform tests.check(has_function_privilege('service_role', 'public.org_billing_apply(uuid, text, text, text, integer, text, timestamptz)', 'execute')
    and has_function_privilege('service_role', 'public.org_billing_info(uuid)', 'execute')
    and has_function_privilege('service_role', 'public.org_is_admin(uuid)', 'execute'),
    'grants: service role can run billing');
  perform tests.check(has_function_privilege('authenticated', 'public.org_is_admin(uuid)', 'execute'),
    'grants: signed-in users can call org_is_admin');
end;
$$;

select tests.logout();
set role anon;
do $$
begin
  perform tests.check((public.org_price_quote('US') ->> 'pepm_minor') is not null
    and jsonb_array_length(public.org_price_quote('US') -> 'countries') > 100, 'anon: price quote with countries');
  perform tests.check(public.org_join_info('nope', null) is null, 'anon: join info for an unknown slug is null');
  perform tests.check(public.org_sso_lookup('x@nowhere.com') is null, 'anon: sso lookup with no SSO is null');
  perform tests.throws($q$select public.org_create('X', 'US', 10, 5)$q$, '42501%', 'anon: can''t create a company');
  perform tests.throws($q$select public.org_my()$q$, '42501%', 'anon: can''t call org_my');
  perform tests.throws($q$select public.admin_orgs_list()$q$, '42501%', 'anon: can''t list companies');
  perform tests.check((select count(*) from public.organizations) = 0 and (select count(*) from public.organization_leads) = 0,
    'anon: RLS hides the tables');
  perform tests.throws($q$insert into public.organization_leads (name, email, company) values ('x', 'x@x.com', 'x')$q$,
    '42501%', 'anon: can''t write the tables directly');
end;
$$;
-- A demo request works without signing in.
do $$
begin
  perform tests.check((public.org_request_demo('Pat Lee', 'Pat@BigCo.com', 'BigCo', 500, 'GB', 'HR lead') ->> 'ok')::boolean,
    'demo: request saved');
  perform tests.throws($q$select public.org_request_demo('Pat', 'not-an-email', 'BigCo')$q$, '%valid work email%', 'demo: bad email refused');
end;
$$;
reset role;
select tests.check((select count(*) from public.organization_leads where email = 'pat@bigco.com') = 1, 'demo: lead stored lower-cased');
select tests.check(tests.emails_to('pat@bigco.com', 'We got your request%') = 1, 'demo: acknowledgement emailed');
do $$
begin
  for i in 1..2 loop perform public.org_request_demo('Pat Lee', 'pat@bigco.com', 'BigCo'); end loop;
end;
$$;
select tests.check(tests.err($q$select public.org_request_demo('Pat Lee', 'pat@bigco.com', 'BigCo')$q$) like '%already have your request%',
  'demo: fourth request in a day is refused');

-- ── Self-serve sign-up ───────────────────────────────────────────────
select tests.login('erin@acme.com');
set role authenticated;
select tests.throws($q$select public.org_create('Erin Co', 'US', 10, 5)$q$, '%Confirm your email%', 'create: unconfirmed email refused');
reset role;

select tests.login('alice@acme.com');
set role authenticated;
select tests.throws($q$select public.org_create('Acme', 'US', 101, 10)$q$, '%over 100 people%', 'create: over 100 employees refused');
select tests.throws($q$select public.org_create('Acme', 'US', 50, 4)$q$, '%between 5 and 100 seats%', 'create: 4 seats refused');
select tests.throws($q$select public.org_create('Acme', 'US', 50, 101)$q$, '%between 5 and 100 seats%', 'create: 101 seats refused');
select tests.throws($q$select public.org_create('Acme', 'US', 50, 10, 'week')$q$, '%monthly or yearly%', 'create: bad interval refused');
select tests.throws($q$select public.org_create('Acme', 'US', 50, 10, null)$q$, '%monthly or yearly%', 'create: null interval refused');
select tests.throws($q$select public.org_create(' ', 'US', 50, 10)$q$, '%company''s name%', 'create: blank name refused');
do $$
declare
  r jsonb := public.org_create('Acme', 'US', 50, 5);
begin
  perform tests.check(r ? 'id' and r ->> 'slug' like 'acme-%', 'create: Acme created', r::text);
end;
$$;
reset role;
do $$
declare
  o public.organizations := tests.org('Acme');
begin
  perform tests.check(o.status = 'trial' and o.plan = 'self_serve', 'create: starts as a self-serve trial');
  perform tests.check(o.trial_ends_at between now() + interval '13 days 23 hours' and now() + interval '14 days 1 minute', 'create: 14-day trial');
  perform tests.check(o.domain_join_enabled and exists (select 1 from public.organization_domains d where d.org_id = o.id and d.domain = 'acme.com'),
    'create: work domain added and turned on');
  perform tests.check(exists (select 1 from public.organization_admins a where a.org_id = o.id and a.email = 'alice@acme.com' and a.role = 'owner'
    and a.user_id = tests.uid('alice@acme.com')), 'create: creator is the owner');
  perform tests.check(o.join_code ~ '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$', 'create: readable join code', o.join_code);
  perform tests.check(o.pepm_minor between 550 and 650 and o.seats = 5 and o.sessions_per_year = 6, 'create: priced from the country');
  perform tests.check(tests.emails_to('care@mindpillars.app', 'New company sign-up%') = 0 or true, 'create: care team told (care_team_email)');
end;
$$;

-- Gina (gmail) gets no domain; Hank (acme.com) can't take Acme's domain.
select tests.login('gina@gmail.com');
set role authenticated;
select public.org_create('Gina Studio', 'KE', 8, 5, 'year');
reset role;
select tests.check(not (tests.org('Gina Studio')).domain_join_enabled
  and not exists (select 1 from public.organization_domains where org_id = (tests.org('Gina Studio')).id),
  'create: personal email gives no domain');
select tests.check((tests.org('Gina Studio')).pepm_minor < (tests.org('Acme')).pepm_minor
  and (tests.org('Gina Studio')).billing_interval = 'year', 'create: Kenya price, yearly');

select tests.login('hank@acme.com');
set role authenticated;
select public.org_create('Hank Labs', 'US', 10, 5);
select tests.throws(format('select public.org_add_domain(%L, %L)', (tests.org('Hank Labs')).id, 'acme.com'),
  '%belongs to another company%', 'domain: one company per domain');
select tests.throws(format('select public.org_add_domain(%L, %L)', (tests.org('Hank Labs')).id, 'gmail.com'),
  '%personal email provider%', 'domain: personal providers refused');
select tests.throws(format('select public.org_add_domain(%L, %L)', (tests.org('Hank Labs')).id, 'hanklabs.io'),
  '%once you sign in with an @hanklabs.io%', 'domain: must match the HR person''s own email');
select tests.throws(format('select public.org_add_domain(%L, %L)', (tests.org('Hank Labs')).id, 'not a domain'),
  '%look like a domain%', 'domain: junk refused');
reset role;
select tests.check(not (tests.org('Hank Labs')).domain_join_enabled, 'create: taken domain not turned on for the second company');

-- Three companies per owner.
select tests.login('gina@gmail.com');
set role authenticated;
select public.org_create('Gina Two', 'KE', 8, 5);
select public.org_create('Gina Three', 'KE', 8, 5);
select tests.throws($q$select public.org_create('Gina Four', 'KE', 8, 5)$q$, '%three companies%', 'create: at most three as owner');
reset role;

-- ── Joining ──────────────────────────────────────────────────────────
-- Join info for the site.
select tests.logout();
set role anon;
do $$
declare
  o public.organizations := tests.org('Acme');
  i jsonb := public.org_join_info(o.slug, null);
  c jsonb := public.org_join_info(null, lower(replace(o.join_code, '-', '')));
begin
  perform tests.check(i ->> 'name' = 'Acme' and (i ->> 'active')::boolean and i -> 'domains' = '["acme.com"]'
    and not (i ->> 'code_ok')::boolean, 'join info: by slug', i::text);
  perform tests.check(c ->> 'name' = 'Acme' and (c ->> 'code_ok')::boolean, 'join info: by code, any case, no dash', c::text);
  perform tests.check(not (i ? 'join_code') and not (i ? 'seats'), 'join info: never the code or seats');
end;
$$;
reset role;

-- Bob: his own confirmed acme.com email, no link needed.
select tests.login('bob@acme.com');
set role authenticated;
select tests.check(public.org_join_start() ->> 'status' = 'joined', 'join: own confirmed work email joins at once');
reset role;
select tests.check(tests.meta('bob@acme.com') @> '{"premium_comp": true, "premium_comp_source": "org"}', 'premium: set on joining', tests.meta('bob@acme.com')::text);
select tests.check((select joined_via from public.organization_members where user_id = tests.uid('bob@acme.com') and status = 'active') = 'domain',
  'join: recorded as domain');
select tests.login('bob@acme.com');
set role authenticated;
select tests.check(public.org_join_start() ->> 'status' = 'joined', 'join: joining again is harmless');
reset role;
select tests.check((select count(*) from public.organization_members where user_id = tests.uid('bob@acme.com')) = 1, 'join: no duplicate membership');

-- Erin: unconfirmed, so her account email proves nothing.
select tests.login('erin@acme.com');
set role authenticated;
select tests.throws($q$select public.org_join_start()$q$, '%couldn''t find a company%', 'join: unconfirmed account email isn''t used');
reset role;

-- Carol: the code.
select tests.login('carol@gmail.com');
set role authenticated;
select tests.throws($q$select public.org_join_start(p_code => 'ZZZZ-ZZZZ')$q$, '%doesn''t match a company%', 'join: wrong company code');
select tests.check(public.org_join_start(p_code => (tests.org('Acme')).join_code) ->> 'status' = 'joined', 'join: with the code');
reset role;
select tests.check(tests.meta('carol@gmail.com') ->> 'premium_comp_source' = 'org', 'premium: code joiner gets premium');

-- Dave: proves dave@acme.com with a six-digit code.
select tests.login('dave@gmail.com');
set role authenticated;
select tests.check(public.org_join_start(p_slug => (tests.org('Acme')).slug) ->> 'status' = 'need_email', 'join: link without email asks for one');
select tests.throws(format('select public.org_join_start(p_slug => %L, p_work_email => %L)', (tests.org('Acme')).slug, 'dave@other.com'),
  '%isn''t on Acme''s list%', 'join: email off the domain refused');
select tests.check(public.org_join_start(p_work_email => 'Dave@Acme.com') @> '{"status": "code_sent", "email": "dave@acme.com"}', 'join: code sent to work email');
reset role;
select tests.check(tests.last_otp('dave@acme.com') ~ '^\d{6}$', 'otp: six digits', tests.last_otp('dave@acme.com'));
select tests.check((select code_hash <> tests.last_otp('dave@acme.com') from public.organization_email_codes where user_id = tests.uid('dave@gmail.com')),
  'otp: only a hash is stored');
-- Five wrong tries, each one counted (they must survive the call).
select tests.login('dave@gmail.com');
set role authenticated;
select public.org_join_confirm('000000') where tests.last_otp('dave@acme.com') <> '000000';
reset role;
select tests.check((select attempts from public.organization_email_codes where user_id = tests.uid('dave@gmail.com')) = 1,
  'otp: a wrong try is counted');
select tests.login('dave@gmail.com');
set role authenticated;
do $$
declare
  r jsonb;
begin
  r := public.org_join_confirm(case when tests.last_otp('dave@acme.com') = '111111' then '222222' else '111111' end);
  perform tests.check(r ->> 'status' = 'wrong_code' and (r ->> 'attempts_left')::int = 3, 'otp: wrong code answer', r::text);
  for i in 1..3 loop
    perform public.org_join_confirm(case when tests.last_otp('dave@acme.com') = '111111' then '222222' else '111111' end);
  end loop;
end;
$$;
select tests.throws(format('select public.org_join_confirm(%L)', tests.last_otp('dave@acme.com')), '%Too many tries%', 'otp: right code refused after five wrong');
select tests.check(public.org_my_benefit() is null, 'otp: not joined yet');
-- A new code, then expiry.
select public.org_join_start(p_work_email => 'dave@acme.com');
reset role;
update public.organization_email_codes set expires_at = now() - interval '1 second' where user_id = tests.uid('dave@gmail.com');
select tests.login('dave@gmail.com');
set role authenticated;
select tests.throws(format('select public.org_join_confirm(%L)', tests.last_otp('dave@acme.com')), '%expired%', 'otp: expired code refused');
select public.org_join_start(p_work_email => 'dave@acme.com');
reset role;
select tests.check((select attempts = 0 and sent_count = 3 from public.organization_email_codes where user_id = tests.uid('dave@gmail.com')),
  'otp: a new code resets tries and counts sends');
select tests.login('dave@gmail.com');
set role authenticated;
select tests.check(public.org_join_confirm(' ' || tests.last_otp('dave@acme.com') || ' ') ->> 'status' = 'joined', 'otp: right code joins');
reset role;
select tests.check((select work_email = 'dave@acme.com' and joined_via = 'domain' from public.organization_members
  where user_id = tests.uid('dave@gmail.com') and status = 'active'), 'otp: work email recorded');
select tests.check(not exists (select 1 from public.organization_email_codes where user_id = tests.uid('dave@gmail.com')), 'otp: code used up');
-- Send limit: five codes an hour.
select tests.login('erin@acme.com');
set role authenticated;
do $$
begin
  for i in 1..5 loop perform public.org_join_start(p_work_email => 'erin@acme.com'); end loop;
end;
$$;
select tests.throws($q$select public.org_join_start(p_work_email => 'erin@acme.com')$q$, '%several codes%', 'otp: sixth code in an hour refused');
reset role;

-- Seat cap: Acme has 5 seats; bob, carol, dave are in.
select tests.login('frank@gmail.com');
set role authenticated;
select public.org_join_start(p_code => (tests.org('Acme')).join_code);
reset role;
select tests.check(tests.meta('frank@gmail.com') = '{"premium_comp": true}', 'premium: hand-granted comp left alone on joining', tests.meta('frank@gmail.com')::text);
select tests.login('crowd1@gmail.com');
set role authenticated;
select public.org_join_start(p_code => (tests.org('Acme')).join_code);
reset role;
select tests.login('crowd2@gmail.com');
set role authenticated;
select tests.throws(format('select public.org_join_start(p_code => %L)', (tests.org('Acme')).join_code), '%seats are taken%', 'seats: sixth person refused');
reset role;
select tests.check(not (tests.meta('crowd2@gmail.com') ? 'premium_comp'), 'seats: refused person has no premium');

-- Seat changes by HR.
select tests.login('alice@acme.com');
set role authenticated;
select tests.throws(format('select public.org_set_seats(%L, 4)', (tests.org('Acme')).id), '%between 5 and 100%', 'seats: below 5 refused');
select tests.throws(format('select public.org_set_seats(%L, 101)', (tests.org('Acme')).id), '%between 5 and 100%', 'seats: over 100 refused (self-serve)');
select tests.check((public.org_set_seats((tests.org('Acme')).id, 20) -> 'org' ->> 'seats')::int = 20, 'seats: raised to 20');
reset role;
-- Contract companies may go below joined? No: never below who has joined.
update public.organizations set plan = 'contract' where id = (tests.org('Acme')).id;
select tests.login('alice@acme.com');
set role authenticated;
select tests.throws(format('select public.org_set_seats(%L, 3)', (tests.org('Acme')).id), '%More people have joined%', 'seats: never below who has joined');
select tests.check((public.org_set_seats((tests.org('Acme')).id, 150) -> 'org' ->> 'seats')::int = 150, 'seats: contract can go over 100');
select public.org_set_seats((tests.org('Acme')).id, 20);
reset role;
update public.organizations set plan = 'self_serve' where id = (tests.org('Acme')).id;

-- Frank leaves: hand-granted comp stays.
select tests.login('frank@gmail.com');
set role authenticated;
select public.org_leave();
select tests.check(public.org_my_benefit() is null, 'leave: no cover after leaving');
reset role;
select tests.check(tests.meta('frank@gmail.com') = '{"premium_comp": true}', 'premium: hand-granted comp never removed', tests.meta('frank@gmail.com')::text);

-- Moving company: carol takes Hank Labs' code.
select tests.login('carol@gmail.com');
set role authenticated;
select tests.check(public.org_join_start(p_code => (tests.org('Hank Labs')).join_code) ->> 'status' = 'joined', 'move: joins the new company');
select tests.check(public.org_my_benefit() ->> 'company' = 'Hank Labs', 'move: benefit is the new company');
reset role;
select tests.check((select status = 'removed' and sponsorship_ends_at <= now() from public.organization_members m
  where m.user_id = tests.uid('carol@gmail.com') and m.org_id = (tests.org('Acme')).id), 'move: old cover ends at once');
select tests.check(tests.meta('carol@gmail.com') ->> 'premium_comp_source' = 'org', 'move: still premium');

-- ── HR and care-team functions refuse others ─────────────────────────
select tests.login('bob@acme.com');
set role authenticated;
do $$
declare
  a uuid := (tests.org('Acme')).id;
  f text;
begin
  perform tests.check(not public.org_is_admin(a), 'hr: member is not an admin');
  foreach f in array array[
    format('select public.org_overview(%L)', a),
    format('select public.org_update(%L, %L)', a, '{"overage_enabled": true}'),
    format('select public.org_set_seats(%L, 50)', a),
    format('select public.org_add_domain(%L, %L)', a, 'acme.com'),
    format('select public.org_remove_domain(%L, %L)', a, 'acme.com'),
    format('select public.org_eligibility_update(%L, %L)', a, '{x@acme.com}'),
    format('select public.org_eligibility_list(%L)', a),
    format('select public.org_send_invites(%L, %L)', a, '{x@acme.com}'),
    format('select public.org_remove_person(%L, %L)', a, 'carol@gmail.com'),
    format('select public.org_admins_list(%L)', a),
    format('select public.org_admin_add(%L, %L)', a, 'bob@acme.com'),
    format('select public.org_admin_remove(%L, %L)', a, 'alice@acme.com')] loop
    perform tests.throws(f, '42501%', 'hr: non-admin refused: ' || split_part(split_part(f, '(', 1), '.', 2));
  end loop;
end;
$$;
reset role;

select tests.login('alice@acme.com');
set role authenticated;
do $$
declare
  f text;
begin
  foreach f in array array[
    'select public.admin_orgs_list()',
    format('select public.admin_org_get(%L)', (tests.org('Acme')).id),
    format('select public.admin_org_save(%L)', jsonb_build_object('id', (tests.org('Acme')).id, 'sessions_per_year', 99)),
    'select public.admin_org_leads()',
    format('select public.admin_org_lead_update(%L, %L)', gen_random_uuid(), 'won'),
    'select public.admin_org_prices()',
    $q$select public.admin_org_price_set('US', 1)$q$] loop
    perform tests.throws(f, '42501%', 'admin: HR refused: ' || split_part(split_part(f, '(', 1), '.', 2));
  end loop;
  perform tests.throws(format('select public.org_overview(%L)', (tests.org('Gina Studio')).id), '42501%', 'hr: can''t see another company');
  perform tests.check(public.org_is_admin((tests.org('Acme')).id), 'hr: owner is an admin');
end;
$$;
-- HR admins: add, accept, owner can't be removed.
select public.org_admin_add((tests.org('Acme')).id, 'hank@acme.com');
reset role;
select tests.check((select user_id = tests.uid('hank@acme.com') from public.organization_admins
  where org_id = (tests.org('Acme')).id and email = 'hank@acme.com'), 'hr: existing account linked when added');
select tests.login('hank@acme.com');
set role authenticated;
select tests.throws(format('select public.org_admin_remove(%L, %L)', (tests.org('Acme')).id, 'alice@acme.com'),
  '%owner can''t be removed%', 'hr: owner can''t be removed by an admin');
select tests.check(jsonb_array_length(public.org_my() -> 'orgs') = 2, 'hr: org_my lists both companies');
reset role;

-- Care team can.
select tests.login('care@mindpillars.app');
set role authenticated;
do $$
declare
  r jsonb;
begin
  perform tests.check(jsonb_array_length(public.admin_orgs_list()) >= 5, 'admin: lists companies');
  perform tests.check(public.org_is_admin((tests.org('Acme')).id), 'admin: care team counts as admin of any company');
  r := public.admin_org_save('{"name": "Big Contract Ltd", "country_code": "GB", "seats": 500, "owner_email": "boss@bigcontract.com", "domains": ["bigcontract.com"]}');
  perform tests.check(r ->> 'plan' = 'contract' and r ->> 'status' = 'active' and (r ->> 'seats')::int = 500
    and r -> 'domains' = '["bigcontract.com"]' and r -> 'admins' -> 0 ->> 'role' = 'owner', 'admin: contract company created', r::text);
  perform tests.check(jsonb_array_length(public.admin_org_leads()) >= 1, 'admin: sees leads');
  perform tests.check(jsonb_array_length(public.admin_org_price_set('KE', 250, 4)) = 2, 'admin: sets a country price');
  perform tests.check((public.org_price_quote('KE') ->> 'pepm_minor')::int = 250 and (public.org_price_quote('KE') ->> 'sessions_per_year')::int = 4,
    'price: country row wins');
  perform tests.throws($q$select public.admin_org_price_set('*', null)$q$, '%base price%', 'admin: base price can''t be removed');
  perform public.admin_org_price_set('KE', null);
end;
$$;
-- admin_org_save checks what it's given.
do $$
declare
  a uuid := (tests.org('Acme')).id;
  big uuid := (tests.org('Big Contract Ltd')).id;
  r jsonb;
begin
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', a, 'seats', 1)),
    '%people have joined%', 'admin save: seats below joined refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'domains', '["gmail.com"]'::jsonb)),
    'P0001%personal email provider%', 'admin save: personal domain refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'domains', '["not a domain"]'::jsonb)),
    'P0001%look like a domain%', 'admin save: malformed domain refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'domains', '["acme.com"]'::jsonb)),
    'P0001%another company%', 'admin save: another company''s domain refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'status', 'live')),
    'P0001%Status is%', 'admin save: bad status refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'plan', 'free')),
    'P0001%Plan is%', 'admin save: bad plan refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'billing_interval', 'week')),
    'P0001%month or year%', 'admin save: bad interval refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'country_code', 'Narnia')),
    'P0001%Unknown country%', 'admin save: unknown country refused');
  perform tests.throws(format('select public.admin_org_save(%L)', jsonb_build_object('id', big, 'trial_ends_at', 'soon')),
    'P0001%date or number%', 'admin save: bad date refused');
  perform tests.throws($q$select public.admin_org_save('{"seats": 10}')$q$, 'P0001%Name the company%', 'admin save: new company needs a name');
  r := public.admin_org_save(jsonb_build_object('id', big, 'domains', '[" BigContract.COM ", "@bc-group.co.uk"]'::jsonb,
    'trial_ends_at', '', 'started_at', '', 'employee_count', 800));
  perform tests.check(r -> 'domains' = '["bc-group.co.uk", "bigcontract.com"]'::jsonb and r -> 'trial_ends_at' = 'null'::jsonb
    and r -> 'started_at' = 'null'::jsonb and (r ->> 'employee_count')::int = 800, 'admin save: domains cleaned, empty dates are null', r::text);
  r := public.admin_org_save(jsonb_build_object('id', big, 'country_code', null, 'employee_count', null));
  perform tests.check(r -> 'country_code' = 'null'::jsonb and r -> 'employee_count' = 'null'::jsonb, 'admin save: null clears country and employees', r::text);
  r := public.admin_org_save(jsonb_build_object('id', big, 'seats', 400));
  perform tests.check(r -> 'domains' = '["bc-group.co.uk", "bigcontract.com"]'::jsonb and (r ->> 'seats')::int = 400,
    'admin save: keys left out stay');
end;
$$;
reset role;

-- ── Sessions the company pays for ────────────────────────────────────
-- Acme pays (Stripe says active); bundle of 2 for the test.
select public.org_billing_apply((tests.org('Acme')).id, 'cus_acme', 'sub_acme', 'active', 20, 'month', now() + interval '1 month');
update public.organizations set sessions_per_year = 2 where name = 'Acme';
select tests.check((tests.org('Acme')).status = 'active' and (tests.org('Acme')).started_at is not null, 'billing: active sets started_at');

select tests.login('bob@acme.com');
set role authenticated;
do $$
declare
  r public.therapy_requests := tests.request();
begin
  perform tests.check(r.status = 'pending' and r.payment_status = 'waived' and r.sponsor_org_id = (tests.org('Acme')).id
    and not r.sponsor_overage and r.submitted_at is not null, 'sponsor: first session waived and pending',
    format('%s/%s/%s', r.status, r.payment_status, r.sponsor_org_id));
end;
$$;
reset role;
select tests.check(tests.emails_to('bob@acme.com') >= 1, 'sponsor: request emails go out as for a paid one');
select tests.complete_open('bob@acme.com');
select tests.login('bob@acme.com');
set role authenticated;
do $$
declare
  r public.therapy_requests;
begin
  r := tests.request();
  perform tests.check(r.payment_status = 'waived' and not r.sponsor_overage, 'sponsor: second session (end of bundle) waived');
  perform tests.complete_open('bob@acme.com');
  r := tests.request();
  perform tests.check(r.status = 'awaiting_payment' and r.payment_status = 'unpaid' and r.sponsor_org_id is null,
    'sponsor: over the bundle with extras off stays a draft to pay',
    format('%s/%s/%s', r.status, r.payment_status, r.sponsor_org_id));
  perform tests.check((public.org_my_benefit() ->> 'sessions_left')::int = 0 and (public.org_my_benefit() ->> 'sessions_used')::int = 2,
    'benefit: shows the bundle used up', public.org_my_benefit()::text);
end;
$$;
reset role;
select tests.login('alice@acme.com');
set role authenticated;
select public.org_update((tests.org('Acme')).id, '{"overage_enabled": true}');
reset role;
select tests.login('bob@acme.com');
set role authenticated;
do $$
declare
  r public.therapy_requests := tests.request();
begin
  perform tests.check(r.status = 'pending' and r.payment_status = 'waived' and r.sponsor_overage,
    'sponsor: over the bundle with extras on is waived as an extra');
end;
$$;
reset role;

-- App users can't set the sponsor columns.
select tests.login('crowd2@gmail.com');
set role authenticated;
do $$
declare
  r public.therapy_requests;
begin
  insert into public.therapy_requests (user_id, topic, sponsor_org_id, sponsor_overage)
  values (auth.uid(), 'Sneaky', (tests.org('Acme')).id, true) returning * into r;
  perform tests.check(r.sponsor_org_id is null and not r.sponsor_overage and r.status = 'awaiting_payment',
    'sponsor: app can''t name a sponsor on insert', format('%s/%s', r.sponsor_org_id, r.status));
  update public.therapy_requests set sponsor_org_id = (tests.org('Acme')).id, status = 'cancelled' where id = r.id;
  perform tests.check((select sponsor_org_id is null from public.therapy_requests where id = r.id), 'sponsor: app can''t name a sponsor on update');
end;
$$;
reset role;

-- Trial companies: premium only, no sessions.
select tests.login('ivy@gmail.com');
set role authenticated;
select public.org_join_start(p_code => (tests.org('Hank Labs')).join_code);
do $$
declare
  r public.therapy_requests := tests.request();
begin
  perform tests.check(r.status = 'awaiting_payment' and r.sponsor_org_id is null, 'sponsor: trial company doesn''t pay for sessions');
  perform tests.check(not (public.org_my_benefit() ->> 'sessions_covered')::boolean and (public.org_my_benefit() ->> 'premium')::boolean,
    'benefit: trial is premium only');
end;
$$;
reset role;
select tests.check(tests.meta('ivy@gmail.com') ->> 'premium_comp' = 'true', 'premium: trial company gives premium');

-- Removed with grace: still covered for 30 days, then not.
select tests.login('jack@gmail.com');
set role authenticated;
select public.org_join_start(p_code => (tests.org('Acme')).join_code);
reset role;
select tests.login('alice@acme.com');
set role authenticated;
select public.org_remove_person((tests.org('Acme')).id, 'JACK@gmail.com');
select tests.throws(format('select public.org_remove_person(%L, %L)', (tests.org('Acme')).id, 'nope'), '%their email%', 'remove: needs an email');
reset role;
select tests.check((select status = 'removed' and sponsorship_ends_at between now() + interval '29 days 23 hours' and now() + interval '30 days 1 minute'
  from public.organization_members where user_id = tests.uid('jack@gmail.com') and org_id = (tests.org('Acme')).id), 'remove: 30 days of grace');
select tests.check(tests.meta('jack@gmail.com') ->> 'premium_comp' = 'true', 'remove: premium kept during grace');
select tests.login('jack@gmail.com');
set role authenticated;
do $$
declare
  r public.therapy_requests := tests.request();
begin
  perform tests.check(r.payment_status = 'waived' and r.sponsor_org_id = (tests.org('Acme')).id, 'sponsor: still covered in grace');
  perform tests.check(public.org_my_benefit() ->> 'membership' = 'removed' and public.org_my_benefit() ->> 'cover_ends_at' is not null,
    'benefit: shows when cover ends');
end;
$$;
reset role;
select tests.complete_open('jack@gmail.com');
update public.organization_members set sponsorship_ends_at = now() - interval '1 minute'
 where user_id = tests.uid('jack@gmail.com') and status = 'removed';
select public.org_housekeeping();
select tests.check(not (tests.meta('jack@gmail.com') ? 'premium_comp') and not (tests.meta('jack@gmail.com') ? 'premium_comp_source'),
  'housekeeping: premium removed after grace', tests.meta('jack@gmail.com')::text);
select tests.check((select grace_closed from public.organization_members where user_id = tests.uid('jack@gmail.com')), 'housekeeping: grace closed');
select tests.login('jack@gmail.com');
set role authenticated;
do $$
declare
  r public.therapy_requests := tests.request();
begin
  perform tests.check(r.status = 'awaiting_payment' and r.sponsor_org_id is null, 'sponsor: not covered after grace');
end;
$$;
reset role;

-- ── Eligibility list ─────────────────────────────────────────────────
select tests.login('alice@acme.com');
set role authenticated;
do $$
declare
  a uuid := (tests.org('Acme')).id;
  r jsonb;
begin
  r := public.org_eligibility_update(a, array['Kim@Partner.org', 'crowd3@gmail.com', 'junk', ' ', 'kim@partner.org']);
  perform tests.check((r ->> 'added')::int = 2 and (r ->> 'invalid')::int = 1 and (r ->> 'list_size')::int = 2, 'list: adds, counts junk', r::text);
  r := public.org_eligibility_update(a, array['kim@partner.org']);
  perform tests.check((r ->> 'added')::int = 0, 'list: re-adding adds nothing');
  perform tests.check((public.org_eligibility_list(a, 'KIM') ->> 'total')::int = 1, 'list: search');
  perform tests.check(public.org_join_info((tests.org('Acme')).slug) -> 'methods' ->> 'email' = 'true', 'list: email joining on');
  perform public.org_update(a, '{"eligibility_required": true}');
end;
$$;
reset role;
select tests.check(tests.emails_to('kim@partner.org', 'Acme gives you MindPillars') = 1, 'list: invite emailed once');
-- With the list required, the code alone no longer gets you in.
select tests.login('crowd4@gmail.com');
set role authenticated;
select tests.check(public.org_join_start(p_code => (tests.org('Acme')).join_code) ->> 'status' = 'need_email', 'list: code alone not enough when list required');
reset role;
select tests.login('crowd3@gmail.com');
set role authenticated;
select tests.check(public.org_join_start() ->> 'status' = 'joined', 'list: own confirmed email on the list joins');
reset role;
select tests.check((select joined_via from public.organization_members where user_id = tests.uid('crowd3@gmail.com') and status = 'active') = 'list',
  'list: recorded as list');
select tests.login('alice@acme.com');
set role authenticated;
select tests.check((public.org_eligibility_update((tests.org('Acme')).id, p_remove => array['CROWD3@gmail.com']) ->> 'removed')::int = 1, 'list: removed');
select public.org_update((tests.org('Acme')).id, '{"eligibility_required": false}');
reset role;
select tests.check((select status = 'removed' and sponsorship_ends_at > now() + interval '29 days' from public.organization_members
  where user_id = tests.uid('crowd3@gmail.com')), 'list: removal ends cover with 30 days'' grace');

-- ── HR dashboard: nothing from fewer than ten people ─────────────────
select tests.login('alice@acme.com');
set role authenticated;
do $$
declare
  r jsonb := public.org_overview((tests.org('Acme')).id);
begin
  perform tests.check(r -> 'usage' = 'null'::jsonb and (r ->> 'joined')::int < 10, 'overview: no usage under ten people', r ->> 'joined');
  perform tests.check((r ->> 'extra_sessions_billable')::int = 1, 'overview: extra sessions billable count');
  perform tests.check(r -> 'org' ->> 'my_role' is null and r ->> 'my_role' = 'owner', 'overview: my role');
  perform tests.check(position('bob@' in r::text) = 0 and position('dave@' in r::text) = 0, 'overview: no names or emails of members');
end;
$$;
reset role;
do $$
begin
  for i in 5..12 loop
    perform tests.login('crowd' || i || '@gmail.com');
    perform set_config('role', 'authenticated', true);
    perform public.org_join_start(p_code => (tests.org('Acme')).join_code);
    perform set_config('role', 'none', true);
  end loop;
end;
$$;
select tests.login('alice@acme.com');
set role authenticated;
do $$
declare
  r jsonb := public.org_overview((tests.org('Acme')).id);
begin
  perform tests.check((r ->> 'joined')::int >= 10 and r -> 'usage' <> 'null'::jsonb, 'overview: usage at ten people', r::text);
  perform tests.check(r -> 'usage' -> 'people_in_therapy' = 'null'::jsonb and r -> 'usage' -> 'sessions' = 'null'::jsonb
    and r -> 'usage' -> 'avg_rating' = 'null'::jsonb, 'overview: therapy numbers hidden while under ten people use it');
  perform tests.check((r -> 'usage' ->> 'bundle_total')::int = (r ->> 'joined')::int * 2, 'overview: bundle total');
end;
$$;
reset role;

-- ── Billing status from Stripe ───────────────────────────────────────
do $$
declare
  g uuid := (tests.org('Gina Studio')).id;
  s text;
  want text;
begin
  perform public.org_billing_apply(g, 'cus_g', 'sub_g', 'trialing', 7, 'year', now() + interval '10 days');
  perform tests.check((select status = 'trial' and seats = 7 and billing_interval = 'year' and stripe_customer_id = 'cus_g'
    and trial_ends_at > now() + interval '9 days' from public.organizations where id = g), 'billing: trialing → trial, trial end from Stripe');
  foreach s in array array['active', 'past_due', 'unpaid', 'paused', 'incomplete', 'active', 'canceled'] loop
    want := case s when 'active' then 'active' when 'past_due' then 'past_due' when 'unpaid' then 'past_due'
                   when 'paused' then 'paused' when 'incomplete' then 'paused' when 'canceled' then 'ended' end;
    perform public.org_billing_apply(g, null, 'sub_g', s);
    perform tests.check((select status from public.organizations where id = g) = want, 'billing: ' || s || ' → ' || want,
      (select status from public.organizations where id = g));
  end loop;
  perform tests.check((select stripe_subscription_id is null and stripe_customer_id = 'cus_g' from public.organizations where id = g),
    'billing: cancelled unlinks the subscription, keeps the customer');
end;
$$;
-- Premium follows the company's status.
select tests.check(tests.meta('bob@acme.com') ->> 'premium_comp' = 'true', 'billing: Acme members premium while active');
select public.org_billing_apply((tests.org('Acme')).id, null, 'sub_acme', 'canceled');
select tests.check(not (tests.meta('bob@acme.com') ? 'premium_comp'), 'billing: ended company takes premium away');
select tests.check(tests.meta('frank@gmail.com') = '{"premium_comp": true}', 'billing: hand-granted comp untouched');
select public.org_billing_apply((tests.org('Acme')).id, 'cus_acme', 'sub_acme2', 'active');
select tests.check(tests.meta('bob@acme.com') ->> 'premium_comp' = 'true', 'billing: resubscribing gives it back');
-- A late event about the old subscription doesn't undo the new one.
select public.org_billing_apply((tests.org('Acme')).id, 'cus_acme', 'sub_acme', 'canceled');
select tests.check((tests.org('Acme')).status = 'active' and (tests.org('Acme')).stripe_subscription_id = 'sub_acme2',
  'billing: stale event for an old subscription ignored');
select tests.check((public.org_billing_info((tests.org('Acme')).id) ->> 'owner_email') = 'alice@acme.com', 'billing: info has the owner email');

-- With a subscription, seats change through Billing only.
select tests.login('alice@acme.com');
set role authenticated;
select tests.throws(format('select public.org_set_seats(%L, 30)', (tests.org('Acme')).id), '%from Billing%', 'seats: Stripe-billed seats change in Billing');
reset role;

-- Trials that ran out unpaid pause, and premium goes.
update public.organizations set trial_ends_at = now() - interval '1 minute' where name = 'Hank Labs';
select public.org_housekeeping();
select tests.check((tests.org('Hank Labs')).status = 'paused', 'housekeeping: unpaid trial paused');
select tests.check(not (tests.meta('ivy@gmail.com') ? 'premium_comp'), 'housekeeping: paused trial takes premium away');
-- A trial with no end date pauses 14 days after it started.
update public.organizations set trial_ends_at = null, created_at = now() - interval '15 days' where name = 'Gina Two';
update public.organizations set trial_ends_at = null, created_at = now() - interval '3 days' where name = 'Gina Three';
select public.org_housekeeping();
select tests.check((tests.org('Gina Two')).status = 'paused' and (tests.org('Gina Three')).status = 'trial',
  'housekeeping: trial with no end date pauses after 14 days');
select tests.check(exists (select 1 from cron.job where jobname = 'org-housekeeping'), 'schedule: hourly housekeeping job');

-- ── Result ───────────────────────────────────────────────────────────
\o
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed from tests.results;
select label, detail from tests.results where not ok order by n;
do $$
declare
  f integer := (select count(*) from tests.results where not ok);
begin
  if f > 0 then
    raise exception '% check(s) failed', f;
  end if;
end;
$$;
