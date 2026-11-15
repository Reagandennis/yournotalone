-- 0033: the therapist workspace. Everything the therapist site
-- (Reagandennis/mindpillars-therapists) used to do by opening an email to
-- the care team now has somewhere to live. Safe to run more than once.
--
--  1. Availability: the hours a therapist works, in their own time zone,
--     days off, and whether they're taking new clients. The care team sees
--     it, and admin_check_therapist_slot() says whether a time suits a
--     therapist before a session is booked. Nothing here blocks a booking.
--  2. Messages to the care team (therapist_tickets): asking to move or
--     cancel a session, a follow-up, a safety concern, a data incident,
--     getting paid, anything else. Each one emails the care team, who reply
--     from the admin page (or by email). Safety and incident ones are urgent.
--  3. Payout details: how a therapist wants to be paid. They can save new
--     ones but only ever read back a masked summary; every change is logged
--     and both they and the care team are emailed.
--  4. Private notes: a therapist's own notes on a session and on a client.
--     No policy and no admin function reads them. They go when the client's
--     account goes.
--  5. Documents: a renewed licence or insurance certificate, uploaded to the
--     private therapist-kyc bucket and checked by the care team. Accepting a
--     licence moves the therapist's expiry date.
--  6. Rules the site already promised: a therapist whose licence has expired
--     can't be given a new session; they're emailed 60, 30, 14, 7 and 1 days
--     before it does; the care team is told when a therapist joins a session
--     more than 15 minutes late.
--  7. Emails: a reminder the day before each session, and the 10-minute
--     reminder now links straight to the therapist's waiting room.
--  8. site_errors: faults the therapist site hits in someone's browser.
--     One row per distinct fault, counted, and the care team is emailed the
--     first time each one appears, or reappears after being marked fixed
--     (no more than six different faults in any hour).
--  9. The therapist agreement moves to the version of 15 November 2026, so
--     everyone is asked to sign again. Deploy the therapist site in the same
--     sitting: its AGREEMENT_VERSION must match.
--
-- Afterwards, to tell therapists who haven't signed the new version:
--   select public.notify_agreement_changed();

begin;

-- ── Small things shared below ────────────────────────────────────────

-- Where the care team reads email. Change it here, once.
create or replace function public.care_team_email()
returns text
language sql
immutable
set search_path = ''
as $$
  select 'reagan.e.owiti@gmail.com'::text;
$$;

create or replace function public.therapist_site_url()
returns text
language sql
immutable
set search_path = ''
as $$
  select 'https://therapists.mindpillars.app'::text;
$$;

-- An email in the house style: a headline, a sentence, a box of labelled
-- rows ([["Label", "value"], ...]; empty values are left out), a footer and
-- a link. Everything passed in is plain text and is escaped here.
create or replace function public.therapist_site_email(
  p_to text,
  p_reply_to text,
  p_subject text,
  p_headline text,
  p_intro text,
  p_box_title text,
  p_rows jsonb,
  p_footer text,
  p_link text,
  p_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_intro text := coalesce(p_intro, '');
  v_footer text := coalesce(p_footer, '');
  v_rows_html text := '';
  v_rows_text text := '';
  r jsonb;
begin
  for r in select e.value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) e loop
    if nullif(trim(coalesce(r ->> 1, '')), '') is not null then
      v_rows_html := v_rows_html || public.email_row(
        public.email_escape(r ->> 0),
        replace(public.email_escape(r ->> 1), E'\n', '<br>'));
      v_rows_text := v_rows_text || (r ->> 0) || ': ' || (r ->> 1) || E'\n';
    end if;
  end loop;
  perform public.send_app_email(
    p_to,
    p_reply_to,
    coalesce(p_subject, 'A message from the care team'),
    public.email_layout(
      public.email_escape(v_intro),
      public.email_escape(coalesce(p_headline, p_subject, '')),
      public.email_escape(v_intro),
      case when v_rows_html = '' then '' else
        public.email_box('#F3F6FC', public.email_escape(coalesce(p_box_title, 'Details')),
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || v_rows_html || '</table>')
      end,
      public.email_escape(v_footer)
        || case when p_link is null then '' else
             ' <a href="' || public.email_escape(p_link) || '">'
             || public.email_escape(regexp_replace(p_link, '^https?://', '')) || '</a>'
           end
    ),
    v_intro || E'\n\n' || v_rows_text
      || case when v_footer = '' and p_link is null then '' else
           E'\n' || v_footer || coalesce(' ' || p_link, '')
         end,
    coalesce(p_key, md5(random()::text))
  );
end;
$$;

-- ── 1. Availability ──────────────────────────────────────────────────

create table if not exists public.therapist_availability (
  therapist_id uuid primary key references public.therapists (id) on delete cascade,
  timezone text not null default 'Africa/Nairobi' check (length(timezone) between 1 and 64),
  -- [{ "day": 1..7 (Monday is 1), "from": minutes after midnight, "to": minutes }]
  hours jsonb not null default '[]',
  max_per_day smallint check (max_per_day between 1 and 12),
  notice_hours smallint not null default 24 check (notice_hours between 0 and 336),
  taking_new_clients boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.therapist_availability enable row level security;
-- No policies: only the security-definer functions below read or write it.

create table if not exists public.therapist_time_off (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  starts_on date not null,
  ends_on date not null,
  note text check (length(note) <= 200),
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);
alter table public.therapist_time_off enable row level security;
create index if not exists therapist_time_off_idx
  on public.therapist_time_off (therapist_id, ends_on);

-- Whether a list of hours is well formed: whole minutes, 0 to 1440, each
-- block ending after it starts, on a day from 1 (Monday) to 7.
create or replace function public.therapist_hours_ok(p_hours jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_hours) = 'array'
    and jsonb_array_length(p_hours) <= 42
    and not exists (
      select 1 from jsonb_array_elements(p_hours) h
      where case
        when jsonb_typeof(h) <> 'object' then true
        when jsonb_typeof(h -> 'day') is distinct from 'number'
          or jsonb_typeof(h -> 'from') is distinct from 'number'
          or jsonb_typeof(h -> 'to') is distinct from 'number' then true
        else (h ->> 'day')::numeric not in (1, 2, 3, 4, 5, 6, 7)
          or (h ->> 'from')::numeric < 0
          or (h ->> 'to')::numeric > 1440
          or (h ->> 'from')::numeric >= (h ->> 'to')::numeric
          or (h ->> 'from')::numeric <> trunc((h ->> 'from')::numeric)
          or (h ->> 'to')::numeric <> trunc((h ->> 'to')::numeric)
      end
    );
$$;

-- A session's time as the therapist reads it: in the time zone they set
-- with their hours, or Nairobi's until they have.
create or replace function public.therapist_local_time(p_therapist_id uuid, p_at timestamptz)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select to_char(p_at at time zone z.tz, 'Dy FMDD Mon, HH24:MI') || ' (' || z.tz || ')'
  from (
    select coalesce(
      (select a.timezone from public.therapist_availability a
        where a.therapist_id = p_therapist_id),
      'Africa/Nairobi') as tz
  ) z;
$$;

create or replace function public.therapist_set_availability(
  p_timezone text,
  p_hours jsonb,
  p_max_per_day integer default null,
  p_notice_hours integer default 24,
  p_taking_new_clients boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_hours jsonb;
  v_taking boolean := coalesce(p_taking_new_clients, true);
  v_was boolean;
  v_name text;
  v_email text;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_timezone is null or not exists (
    select 1 from pg_catalog.pg_timezone_names z where z.name = p_timezone
  ) then
    raise exception 'Choose your time zone.' using errcode = '22023';
  end if;
  if not public.therapist_hours_ok(coalesce(p_hours, '[]'::jsonb)) then
    raise exception 'Those hours don’t look right. Check that each one ends after it starts.'
      using errcode = '22023';
  end if;
  if p_max_per_day is not null and p_max_per_day not between 1 and 12 then
    raise exception 'Sessions a day should be between 1 and 12.' using errcode = '22023';
  end if;
  if coalesce(p_notice_hours, 24) not between 0 and 336 then
    raise exception 'Notice should be between 0 hours and 14 days.' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'day', (h ->> 'day')::numeric::integer,
           'from', (h ->> 'from')::numeric::integer,
           'to', (h ->> 'to')::numeric::integer)
           order by (h ->> 'day')::numeric, (h ->> 'from')::numeric), '[]'::jsonb)
    into v_hours
    from jsonb_array_elements(coalesce(p_hours, '[]'::jsonb)) h;

  select a.taking_new_clients into v_was
    from public.therapist_availability a where a.therapist_id = me;

  insert into public.therapist_availability
    (therapist_id, timezone, hours, max_per_day, notice_hours, taking_new_clients, updated_at)
  values (me, p_timezone, v_hours, p_max_per_day, coalesce(p_notice_hours, 24), v_taking, now())
  on conflict (therapist_id) do update
  set timezone = excluded.timezone,
      hours = excluded.hours,
      max_per_day = excluded.max_per_day,
      notice_hours = excluded.notice_hours,
      taking_new_clients = excluded.taking_new_clients,
      updated_at = now();

  -- The care team hears when someone stops or starts taking new clients.
  if coalesce(v_was, true) is distinct from v_taking then
    select t.full_name, ta.email into v_name, v_email
      from public.therapists t
      left join public.therapist_accounts ta on ta.therapist_id = t.id
     where t.id = me;
    perform public.therapist_site_email(
      public.care_team_email(),
      v_email,
      coalesce(v_name, 'A therapist')
        || case when v_taking then ' is taking new clients again' else ' has paused new clients' end,
      case when v_taking then 'Taking new clients again' else 'New clients paused' end,
      coalesce(v_name, 'A therapist')
        || case when v_taking
             then ' has switched new clients back on in their workspace.'
             else ' has paused new clients in their workspace. Sessions already booked aren’t affected, and clients they already see can still be booked with them.'
           end,
      null, null, null, null,
      'therapist-taking/' || me || '/' || extract(epoch from now())::bigint
    );
  end if;
end;
$$;

create or replace function public.therapist_add_time_off(
  p_starts_on date,
  p_ends_on date,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_id uuid;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_starts_on is null or p_ends_on is null or p_ends_on < p_starts_on then
    raise exception 'Choose the first and last day you’re away.' using errcode = '22023';
  end if;
  if p_ends_on < current_date - 1 then
    raise exception 'Those days have already passed.' using errcode = '22023';
  end if;
  if p_ends_on - p_starts_on > 366 then
    raise exception 'That’s more than a year. Ask the care team to pause your profile instead.'
      using errcode = '22023';
  end if;
  if (select count(*) from public.therapist_time_off o
       where o.therapist_id = me and o.ends_on >= current_date) >= 40 then
    raise exception 'That’s a lot of days off to keep track of. Remove some first.'
      using errcode = '22023';
  end if;
  insert into public.therapist_time_off (therapist_id, starts_on, ends_on, note)
  values (me, p_starts_on, p_ends_on, nullif(left(trim(coalesce(p_note, '')), 200), ''))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.therapist_remove_time_off(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  delete from public.therapist_time_off o where o.id = p_id and o.therapist_id = me;
end;
$$;

-- For the care team, before booking: does this time suit this therapist?
-- { ok, reasons: [...], blocks: [...], timezone, local_time, has_hours }.
-- reasons is everything worth knowing; blocks is the part of it that will
-- refuse the booking (a paused profile, no signed agreement, a licence that
-- has already expired). The rest only advises.
create or replace function public.admin_check_therapist_slot(
  p_therapist_id uuid,
  p_at timestamptz,
  p_minutes integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t public.therapists%rowtype;
  a public.therapist_availability%rowtype;
  v_email text;
  v_tz text;
  v_local timestamp;
  v_day integer;
  v_from integer;
  v_reasons text[] := '{}';
  v_blocks text[] := '{}';
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into t from public.therapists where id = p_therapist_id;
  if not found then
    raise exception 'That therapist no longer exists.' using errcode = 'P0002';
  end if;
  if p_at is null then
    raise exception 'Pick a time.' using errcode = '22023';
  end if;
  select * into a from public.therapist_availability where therapist_id = p_therapist_id;
  select ta.email into v_email
    from public.therapist_accounts ta where ta.therapist_id = p_therapist_id;
  v_tz := coalesce(a.timezone, 'Africa/Nairobi');
  v_local := p_at at time zone v_tz;
  v_day := extract(isodow from v_local)::integer;
  v_from := (extract(hour from v_local) * 60 + extract(minute from v_local))::integer;

  if not t.active then
    v_blocks := array_append(v_blocks, 'Their profile is paused.');
  end if;
  if v_email is null or public.therapist_accepted_agreement(v_email) is null then
    v_blocks := array_append(v_blocks, 'They haven’t signed the current agreement.');
  end if;
  if t.licence_expires_on is not null and t.licence_expires_on < current_date then
    v_blocks := array_append(v_blocks,
      'Their licence expired on ' || to_char(t.licence_expires_on, 'FMDD Mon YYYY') || '.');
  elsif t.licence_expires_on is not null and t.licence_expires_on < v_local::date then
    v_reasons := array_append(v_reasons,
      'Their licence expires on ' || to_char(t.licence_expires_on, 'FMDD Mon YYYY') || ', before this session.');
  end if;
  v_reasons := v_blocks || v_reasons;
  if a.therapist_id is not null then
    if not a.taking_new_clients then
      v_reasons := array_append(v_reasons,
        'They’ve paused new clients (fine for someone they already see).');
    end if;
    if jsonb_array_length(a.hours) > 0 and not exists (
      select 1 from jsonb_array_elements(a.hours) h
      where (h ->> 'day')::integer = v_day
        and (h ->> 'from')::integer <= v_from
        and (h ->> 'to')::integer >= v_from + coalesce(p_minutes, 50)
    ) then
      v_reasons := array_append(v_reasons,
        'Outside the hours they work (' || to_char(v_local, 'Dy HH24:MI') || ' their time).');
    end if;
    if p_at < now() + make_interval(hours => a.notice_hours) then
      v_reasons := array_append(v_reasons,
        'Less than the ' || a.notice_hours || ' hours’ notice they ask for.');
    end if;
    if a.max_per_day is not null and (
      select count(*) from public.therapy_requests r
      where r.therapist_id = p_therapist_id and r.status = 'confirmed'
        and (r.scheduled_at at time zone v_tz)::date = v_local::date
    ) >= a.max_per_day then
      v_reasons := array_append(v_reasons,
        'They already have ' || a.max_per_day || ' that day, the most they take.');
    end if;
  end if;
  if exists (
    select 1 from public.therapist_time_off o
    where o.therapist_id = p_therapist_id
      and v_local::date between o.starts_on and o.ends_on
  ) then
    v_reasons := array_append(v_reasons, 'They’re away that day.');
  end if;

  return jsonb_build_object(
    'ok', coalesce(array_length(v_reasons, 1), 0) = 0,
    'reasons', to_jsonb(v_reasons),
    'blocks', to_jsonb(v_blocks),
    'timezone', v_tz,
    'local_time', to_char(v_local, 'Dy FMDD Mon, HH24:MI'),
    'has_hours', a.therapist_id is not null and jsonb_array_length(a.hours) > 0
  );
end;
$$;

-- Every therapist's hours and days off, for the care team.
create or replace function public.admin_list_therapist_availability()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'therapist_id', t.id,
    'full_name', t.full_name,
    'active', t.active,
    'timezone', a.timezone,
    'hours', coalesce(a.hours, '[]'::jsonb),
    'max_per_day', a.max_per_day,
    'notice_hours', a.notice_hours,
    'taking_new_clients', coalesce(a.taking_new_clients, true),
    'updated_at', a.updated_at,
    'time_off', coalesce((
      select jsonb_agg(jsonb_build_object(
        'starts_on', o.starts_on, 'ends_on', o.ends_on, 'note', o.note) order by o.starts_on)
      from public.therapist_time_off o
      where o.therapist_id = t.id and o.ends_on >= current_date), '[]'::jsonb)
  ) order by t.full_name), '[]'::jsonb)
  into result
  from public.therapists t
  left join public.therapist_availability a on a.therapist_id = t.id;
  return result;
end;
$$;

-- ── 2. Messages to the care team ─────────────────────────────────────

create table if not exists public.therapist_tickets (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  kind text not null check (kind in (
    'session_cancel', 'session_move', 'follow_up', 'safety', 'incident',
    'licence', 'insurance', 'payout', 'profile', 'account', 'technical', 'other')),
  subject text not null check (length(trim(subject)) between 3 and 160),
  request_id uuid references public.therapy_requests (id) on delete set null,
  details jsonb not null default '{}',
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  urgent boolean not null default false,
  closed_by text check (closed_by in ('therapist', 'care')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);
alter table public.therapist_tickets enable row level security;
create index if not exists therapist_tickets_mine_idx
  on public.therapist_tickets (therapist_id, updated_at desc);
create index if not exists therapist_tickets_open_idx
  on public.therapist_tickets (updated_at desc) where status <> 'closed';

create table if not exists public.therapist_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.therapist_tickets (id) on delete cascade,
  author text not null check (author in ('therapist', 'care')),
  author_email text,
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
alter table public.therapist_ticket_messages enable row level security;
create index if not exists therapist_ticket_messages_idx
  on public.therapist_ticket_messages (ticket_id, created_at);

create or replace function public.therapist_ticket_kind_label(p_kind text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'session_cancel' then 'Can’t make a session'
    when 'session_move' then 'Move a session'
    when 'follow_up' then 'Book a follow-up'
    when 'safety' then 'Safety concern'
    when 'incident' then 'Data or confidentiality incident'
    when 'licence' then 'Licence'
    when 'insurance' then 'Insurance'
    when 'payout' then 'Getting paid'
    when 'profile' then 'Name, credentials or profile'
    when 'account' then 'Account'
    when 'technical' then 'Technical problem'
    else 'Something else'
  end;
$$;

create or replace function public.therapist_open_ticket(
  p_kind text,
  p_subject text,
  p_body text,
  p_request_id uuid default null,
  p_details jsonb default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_id uuid;
  v_subject text := left(trim(regexp_replace(coalesce(p_subject, ''), '\s+', ' ', 'g')), 160);
  v_body text := trim(coalesce(p_body, ''));
  v_urgent boolean := p_kind in ('safety', 'incident');
  v_details jsonb := coalesce(p_details, '{}'::jsonb);
  v_name text;
  v_email text;
  v_scheduled timestamptz;
  v_client_id uuid;
  v_client text;
  v_client_email text;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in (
    'session_cancel', 'session_move', 'follow_up', 'safety', 'incident',
    'licence', 'insurance', 'payout', 'profile', 'account', 'technical', 'other') then
    raise exception 'Choose what it’s about.' using errcode = '22023';
  end if;
  if length(v_subject) < 3 then
    v_subject := public.therapist_ticket_kind_label(p_kind);
  end if;
  if length(v_body) < 2 then
    raise exception 'Tell us a little about it first.' using errcode = '22023';
  end if;
  if length(v_body) > 4000 then
    raise exception 'That’s a little long. Shorten it to 4,000 characters.' using errcode = '22023';
  end if;
  if jsonb_typeof(v_details) <> 'object' or length(v_details::text) > 4000 then
    v_details := '{}'::jsonb;
  end if;
  if p_request_id is not null then
    select r.scheduled_at, r.user_id into v_scheduled, v_client_id
      from public.therapy_requests r
     where r.id = p_request_id and r.therapist_id = me;
    if not found then
      raise exception 'That session isn’t one of yours.' using errcode = 'P0002';
    end if;
  end if;
  -- 30 a day, and urgent ones on top of that: those must always get through,
  -- short of someone holding the button down.
  if (not v_urgent and (
        select count(*) from public.therapist_tickets t
        where t.therapist_id = me and not t.urgent and t.created_at > now() - interval '24 hours') >= 30)
     or (v_urgent and (
        select count(*) from public.therapist_tickets t
        where t.therapist_id = me and t.urgent and t.created_at > now() - interval '1 hour') >= 20) then
    raise exception 'You’ve sent a lot of messages today. For anything more, email the care team.'
      using errcode = '22023';
  end if;

  insert into public.therapist_tickets (therapist_id, kind, subject, request_id, details, urgent)
  values (me, p_kind, v_subject, p_request_id, v_details, v_urgent)
  returning id into v_id;

  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = me;

  insert into public.therapist_ticket_messages (ticket_id, author, author_email, body)
  values (v_id, 'therapist', v_email, v_body);

  if v_client_id is not null then
    select nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                                u.raw_user_meta_data ->> 'name', '')), ''),
           u.email::text
      into v_client, v_client_email
      from auth.users u where u.id = v_client_id;
  end if;

  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    case when v_urgent then 'URGENT: ' else '' end
      || public.therapist_ticket_kind_label(p_kind) || ' — ' || coalesce(v_name, 'a therapist'),
    case when v_urgent then 'Urgent: ' || lower(public.therapist_ticket_kind_label(p_kind))
         else public.therapist_ticket_kind_label(p_kind) end,
    coalesce(v_name, 'A therapist') || ' wrote to the care team from their workspace.',
    v_subject,
    jsonb_build_array(
      jsonb_build_array('From', coalesce(v_name, '') || coalesce(' <' || v_email || '>', '')),
      jsonb_build_array('Session', case when p_request_id is null then null
        when v_scheduled is null then 'Not scheduled yet'
        else public.email_session_time(v_scheduled) end),
      jsonb_build_array('Client', case when p_request_id is null then null
        else coalesce(v_client, 'No name') || coalesce(' <' || v_client_email || '>', '') end),
      jsonb_build_array('Message', v_body)
    ),
    'Reply from the admin page, under Therapy → Messages, so they see it in their workspace. Replying to this email reaches them by email only.',
    null,
    'therapist-ticket/' || v_id
  );
  return v_id;
end;
$$;

create or replace function public.therapist_reply_ticket(p_ticket_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_body text := trim(coalesce(p_body, ''));
  tk public.therapist_tickets%rowtype;
  v_name text;
  v_email text;
  v_message uuid;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select * into tk from public.therapist_tickets t
   where t.id = p_ticket_id and t.therapist_id = me for update;
  if not found then
    raise exception 'That message isn’t one of yours.' using errcode = 'P0002';
  end if;
  if length(v_body) < 1 then
    raise exception 'Write your reply first.' using errcode = '22023';
  end if;
  if length(v_body) > 4000 then
    raise exception 'That’s a little long. Shorten it to 4,000 characters.' using errcode = '22023';
  end if;
  if (select count(*) from public.therapist_ticket_messages m
       where m.ticket_id = p_ticket_id and m.created_at > now() - interval '1 hour') >= 30 then
    raise exception 'That’s a lot of replies in an hour. Give the care team a moment.'
      using errcode = '22023';
  end if;

  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = me;
  insert into public.therapist_ticket_messages (ticket_id, author, author_email, body)
  values (p_ticket_id, 'therapist', v_email, v_body)
  returning id into v_message;
  update public.therapist_tickets
     set status = 'open', closed_at = null, closed_by = null, updated_at = now()
   where id = p_ticket_id;

  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    case when tk.urgent then 'URGENT: ' else '' end
      || 'Re: ' || tk.subject || ' — ' || coalesce(v_name, 'a therapist'),
    'A reply from ' || coalesce(v_name, 'a therapist'),
    coalesce(v_name, 'A therapist') || ' replied in their workspace.',
    tk.subject,
    jsonb_build_array(
      jsonb_build_array('About', public.therapist_ticket_kind_label(tk.kind)),
      jsonb_build_array('Message', v_body)
    ),
    'Reply from the admin page, under Therapy → Messages.',
    null,
    'therapist-ticket/' || p_ticket_id || '/' || v_message
  );
end;
$$;

-- "No longer needed": the therapist closes their own message.
create or replace function public.therapist_close_ticket(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  tk public.therapist_tickets%rowtype;
  v_name text;
  v_email text;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select * into tk from public.therapist_tickets t
   where t.id = p_ticket_id and t.therapist_id = me for update;
  if not found then
    raise exception 'That message isn’t one of yours.' using errcode = 'P0002';
  end if;
  if tk.status = 'closed' then
    return;
  end if;
  update public.therapist_tickets
     set status = 'closed', closed_at = now(), closed_by = 'therapist', updated_at = now()
   where id = p_ticket_id;
  if tk.status = 'open' then
    select t.full_name, ta.email into v_name, v_email
      from public.therapists t
      left join public.therapist_accounts ta on ta.therapist_id = t.id
     where t.id = me;
    perform public.therapist_site_email(
      public.care_team_email(),
      v_email,
      'No longer needed: ' || tk.subject || ' — ' || coalesce(v_name, 'a therapist'),
      'No longer needed',
      coalesce(v_name, 'A therapist') || ' closed this message themselves. Nothing more to do.',
      tk.subject,
      jsonb_build_array(jsonb_build_array('About', public.therapist_ticket_kind_label(tk.kind))),
      null, null,
      'therapist-ticket/' || p_ticket_id || '/closed'
    );
  end if;
end;
$$;

create or replace function public.therapist_list_tickets()
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
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.updated_at desc), '[]'::jsonb)
    into result
  from (
    select t.id, t.kind, t.subject, t.request_id, t.status, t.urgent, t.details,
           t.created_at, t.updated_at, t.closed_at, t.closed_by,
           coalesce((
             select jsonb_agg(jsonb_build_object(
               'id', m.id, 'author', m.author, 'body', m.body, 'created_at', m.created_at)
               order by m.created_at)
             from public.therapist_ticket_messages m where m.ticket_id = t.id), '[]'::jsonb) as messages
    from public.therapist_tickets t
    where t.therapist_id = me
    order by t.updated_at desc
    limit 200
  ) q;
  return result;
end;
$$;

-- The care team's inbox: open ones first, urgent ones on top.
create or replace function public.admin_list_therapist_tickets(p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by (q.status = 'open') desc, q.urgent desc, q.updated_at desc), '[]'::jsonb)
    into result
  from (
    select t.id, t.kind, public.therapist_ticket_kind_label(t.kind) as kind_label,
           t.subject, t.request_id, t.status, t.urgent, t.details,
           t.created_at, t.updated_at, t.closed_at, t.closed_by,
           t.therapist_id, th.full_name as therapist_name, ta.email as therapist_email,
           r.scheduled_at as session_at,
           (select nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                                        u.raw_user_meta_data ->> 'name', '')), '')
              from auth.users u where u.id = r.user_id) as client_name,
           (select u.email::text from auth.users u where u.id = r.user_id) as client_email,
           coalesce((
             select jsonb_agg(jsonb_build_object(
               'id', m.id, 'author', m.author, 'author_email', m.author_email,
               'body', m.body, 'created_at', m.created_at) order by m.created_at)
             from public.therapist_ticket_messages m where m.ticket_id = t.id), '[]'::jsonb) as messages
    from public.therapist_tickets t
    join public.therapists th on th.id = t.therapist_id
    left join public.therapist_accounts ta on ta.therapist_id = t.therapist_id
    left join public.therapy_requests r on r.id = t.request_id
    where p_status is null or t.status = p_status
    order by t.updated_at desc
    limit 500
  ) q;
  return result;
end;
$$;

-- The care team answers, and can close it. The therapist is emailed and
-- sees the reply in their workspace.
create or replace function public.admin_reply_therapist_ticket(
  p_ticket_id uuid,
  p_body text,
  p_close boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text := trim(coalesce(p_body, ''));
  tk public.therapist_tickets%rowtype;
  v_name text;
  v_email text;
  v_message uuid;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into tk from public.therapist_tickets t where t.id = p_ticket_id for update;
  if not found then
    raise exception 'That message no longer exists.' using errcode = 'P0002';
  end if;
  if length(v_body) > 4000 then
    raise exception 'That’s a little long. Shorten it to 4,000 characters.' using errcode = '22023';
  end if;
  if v_body = '' and not coalesce(p_close, false) then
    raise exception 'Write a reply, or close it.' using errcode = '22023';
  end if;

  if v_body <> '' then
    insert into public.therapist_ticket_messages (ticket_id, author, author_email, body)
    values (p_ticket_id, 'care', public.current_user_email(), v_body)
    returning id into v_message;
  end if;
  update public.therapist_tickets
     set status = case when coalesce(p_close, false) then 'closed' else 'answered' end,
         closed_at = case when coalesce(p_close, false) then now() end,
         closed_by = case when coalesce(p_close, false) then 'care' end,
         updated_at = now()
   where id = p_ticket_id;

  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = tk.therapist_id;
  if v_body = '' and tk.status <> 'closed' then
    -- Closed with nothing said: they still hear that it's been dealt with.
    perform public.therapist_site_email(
      v_email,
      public.care_team_email(),
      'Closed: ' || tk.subject,
      'The care team closed your message',
      'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ', the care team has dealt with your message and closed it.',
      tk.subject,
      jsonb_build_array(jsonb_build_array('About', public.therapist_ticket_kind_label(tk.kind))),
      'If there’s more to say, reply in your workspace and it opens again:',
      public.therapist_site_url() || '/messages/' || p_ticket_id,
      'therapist-ticket/' || p_ticket_id || '/closed-by-care'
    );
  end if;
  if v_body <> '' then
    perform public.therapist_site_email(
      v_email,
      public.care_team_email(),
      'The care team replied: ' || tk.subject,
      'A reply from the care team',
      'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ', the care team has replied to your message.',
      tk.subject,
      jsonb_build_array(jsonb_build_array('Reply', v_body)),
      'Read it, and answer, in your workspace:',
      public.therapist_site_url() || '/messages/' || p_ticket_id,
      'therapist-ticket/' || p_ticket_id || '/' || v_message
    );
  end if;
end;
$$;

-- ── 3. Payout details ────────────────────────────────────────────────

create table if not exists public.therapist_payout_details (
  therapist_id uuid primary key references public.therapists (id) on delete cascade,
  method text not null check (method in ('mpesa', 'bank', 'paypal', 'wise')),
  account_name text not null check (length(trim(account_name)) between 2 and 120),
  -- mpesa: { phone }   bank: { bank_name, account_number, branch, swift, country }
  -- paypal, wise: { email }
  details jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.therapist_payout_details enable row level security;

-- Every version anyone has saved, so a change can always be traced.
create table if not exists public.therapist_payout_detail_changes (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  method text not null,
  account_name text not null,
  details jsonb not null,
  changed_by uuid,
  changed_at timestamptz not null default now()
);
alter table public.therapist_payout_detail_changes enable row level security;
create index if not exists therapist_payout_detail_changes_idx
  on public.therapist_payout_detail_changes (therapist_id, changed_at desc);

-- "M-Pesa · +2547 ••• 678": enough to recognise, not enough to copy.
create or replace function public.therapist_payout_summary(p_method text, p_details jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_method
    when 'mpesa' then 'M-Pesa · '
      || left(p_details ->> 'phone', 5) || ' ••• ' || right(p_details ->> 'phone', 3)
    when 'bank' then coalesce(p_details ->> 'bank_name', 'Bank')
      || ' · account ending ' || right(regexp_replace(p_details ->> 'account_number', '[^A-Za-z0-9]', '', 'g'), 4)
    when 'paypal' then 'PayPal · '
      || left(p_details ->> 'email', 2) || '•••@' || split_part(p_details ->> 'email', '@', 2)
    when 'wise' then 'Wise · '
      || left(p_details ->> 'email', 2) || '•••@' || split_part(p_details ->> 'email', '@', 2)
    else null
  end;
$$;

create or replace function public.therapist_save_payout_details(
  p_method text,
  p_account_name text,
  p_details jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  d jsonb := coalesce(p_details, '{}'::jsonb);
  v_name_on text := trim(regexp_replace(coalesce(p_account_name, ''), '\s+', ' ', 'g'));
  v_details jsonb;
  v_phone text;
  v_account text;
  v_swift text;
  v_country text;
  v_mail text;
  v_summary text;
  v_name text;
  v_email text;
  v_had boolean;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_method is null or p_method not in ('mpesa', 'bank', 'paypal', 'wise') then
    raise exception 'Choose how you’d like to be paid.' using errcode = '22023';
  end if;
  if length(v_name_on) not between 2 and 120 then
    raise exception 'Enter the name on the account, as it appears there.' using errcode = '22023';
  end if;
  if jsonb_typeof(d) <> 'object' then
    raise exception 'Those details don’t look right.' using errcode = '22023';
  end if;

  if p_method = 'mpesa' then
    v_phone := regexp_replace(coalesce(d ->> 'phone', ''), '[\s()-]', '', 'g');
    if v_phone !~ '^\+[0-9]{7,15}$' then
      raise exception 'Enter the M-Pesa number with its country code, like +254712345678.'
        using errcode = '22023';
    end if;
    v_details := jsonb_build_object('phone', v_phone);
  elsif p_method = 'bank' then
    v_account := trim(coalesce(d ->> 'account_number', ''));
    v_swift := upper(regexp_replace(coalesce(d ->> 'swift', ''), '\s', '', 'g'));
    v_country := upper(trim(coalesce(d ->> 'country', '')));
    if length(trim(coalesce(d ->> 'bank_name', ''))) not between 2 and 120 then
      raise exception 'Enter the name of your bank.' using errcode = '22023';
    end if;
    if v_account !~ '^[A-Za-z0-9][A-Za-z0-9 -]{3,39}$' then
      raise exception 'Enter your account number or IBAN: letters and numbers only.'
        using errcode = '22023';
    end if;
    if v_swift <> '' and v_swift !~ '^[A-Z0-9]{8}([A-Z0-9]{3})?$' then
      raise exception 'A SWIFT or BIC code has 8 or 11 letters and numbers.' using errcode = '22023';
    end if;
    if v_country <> '' and v_country !~ '^[A-Z]{2}$' then
      raise exception 'Choose the country your bank is in.' using errcode = '22023';
    end if;
    v_details := jsonb_strip_nulls(jsonb_build_object(
      'bank_name', left(trim(d ->> 'bank_name'), 120),
      'account_number', v_account,
      'branch', nullif(left(trim(coalesce(d ->> 'branch', '')), 120), ''),
      'swift', nullif(v_swift, ''),
      'country', nullif(v_country, '')));
  else
    v_mail := lower(trim(coalesce(d ->> 'email', '')));
    if length(v_mail) > 200 or v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
      raise exception 'Enter the email address of your % account.',
        case p_method when 'paypal' then 'PayPal' else 'Wise' end using errcode = '22023';
    end if;
    v_details := jsonb_build_object('email', v_mail);
  end if;

  if (select count(*) from public.therapist_payout_detail_changes c
       where c.therapist_id = me and c.changed_at > now() - interval '24 hours') >= 5 then
    raise exception 'You’ve changed your payout details several times today. Message the care team if something’s wrong.'
      using errcode = '22023';
  end if;

  select true into v_had from public.therapist_payout_details p where p.therapist_id = me;
  insert into public.therapist_payout_details (therapist_id, method, account_name, details, updated_at)
  values (me, p_method, v_name_on, v_details, now())
  on conflict (therapist_id) do update
  set method = excluded.method, account_name = excluded.account_name,
      details = excluded.details, updated_at = now();
  insert into public.therapist_payout_detail_changes (therapist_id, method, account_name, details, changed_by)
  values (me, p_method, v_name_on, v_details, auth.uid());

  v_summary := public.therapist_payout_summary(p_method, v_details);
  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = me;

  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    'Payout details ' || case when coalesce(v_had, false) then 'changed' else 'added' end
      || ' — ' || coalesce(v_name, 'a therapist'),
    'Payout details ' || case when coalesce(v_had, false) then 'changed' else 'added' end,
    coalesce(v_name, 'A therapist') || ' saved how they’d like to be paid.',
    'Pay them by',
    jsonb_build_array(
      jsonb_build_array('Method', v_summary),
      jsonb_build_array('Name on account', v_name_on)
    ),
    'The full details are on the admin page, under Therapy → Payouts. If this change is unexpected, check with them before the next payout.',
    null,
    'therapist-payout-details/' || me || '/' || extract(epoch from now())::bigint
  );
  -- And the therapist, so a change they didn't make doesn't go unnoticed.
  perform public.therapist_site_email(
    v_email,
    public.care_team_email(),
    'Your payout details were ' || case when coalesce(v_had, false) then 'changed' else 'saved' end,
    'Your payout details were ' || case when coalesce(v_had, false) then 'changed' else 'saved' end,
    'Hi ' || split_part(coalesce(v_name, ''), ' ', 1)
      || ', we’ll pay your earnings to the details you just saved in your workspace.',
    'Paying you by',
    jsonb_build_array(
      jsonb_build_array('Method', v_summary),
      jsonb_build_array('Name on account', v_name_on)
    ),
    'If you didn’t do this, reply to this email straight away and change your password.',
    null,
    'therapist-payout-details/' || me || '/' || extract(epoch from now())::bigint || '/self'
  );
  return v_summary;
end;
$$;

-- For paying people: the details in full, with what each is owed nearby in
-- admin_therapist_balances().
create or replace function public.admin_list_therapist_payout_details()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'therapist_id', t.id,
    'full_name', t.full_name,
    'email', ta.email,
    'country_code', t.country_code,
    'method', p.method,
    'account_name', p.account_name,
    'details', p.details,
    'summary', public.therapist_payout_summary(p.method, p.details),
    'updated_at', p.updated_at,
    'changes', (select count(*) from public.therapist_payout_detail_changes c
                 where c.therapist_id = t.id)
  ) order by t.full_name), '[]'::jsonb)
  into result
  from public.therapists t
  left join public.therapist_accounts ta on ta.therapist_id = t.id
  left join public.therapist_payout_details p on p.therapist_id = t.id;
  return result;
end;
$$;

-- ── 4. Private notes ─────────────────────────────────────────────────

create table if not exists public.therapist_session_notes (
  request_id uuid not null references public.therapy_requests (id) on delete cascade,
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  body text not null check (length(body) between 1 and 20000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (request_id, therapist_id)
);
alter table public.therapist_session_notes enable row level security;
create index if not exists therapist_session_notes_mine_idx
  on public.therapist_session_notes (therapist_id);

create table if not exists public.therapist_client_notes (
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  client_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (length(body) between 1 and 20000),
  updated_at timestamptz not null default now(),
  primary key (therapist_id, client_id)
);
alter table public.therapist_client_notes enable row level security;

-- A therapist's own notes: one per session, and one running note per
-- client, keyed the way therapist_list_sessions() keys clients.
create or replace function public.therapist_list_notes()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id', n.request_id, 'body', n.body, 'updated_at', n.updated_at))
      from public.therapist_session_notes n where n.therapist_id = me), '[]'::jsonb),
    'clients', coalesce((
      select jsonb_agg(jsonb_build_object(
        'client_key', left(md5(me::text || ':' || c.client_id::text), 16),
        'body', c.body, 'updated_at', c.updated_at))
      from public.therapist_client_notes c where c.therapist_id = me), '[]'::jsonb)
  );
end;
$$;

-- Saving an empty note removes it. Returns when it was saved.
create or replace function public.therapist_save_session_note(p_request_id uuid, p_body text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_body text := coalesce(p_body, '');
  v_at timestamptz := now();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.therapy_requests r
    where r.id = p_request_id and r.therapist_id = me
  ) then
    raise exception 'That session isn’t one of yours.' using errcode = 'P0002';
  end if;
  if length(v_body) > 20000 then
    raise exception 'That note is too long to save. Shorten it to 20,000 characters.'
      using errcode = '22023';
  end if;
  if trim(v_body) = '' then
    delete from public.therapist_session_notes n
     where n.request_id = p_request_id and n.therapist_id = me;
    return null;
  end if;
  insert into public.therapist_session_notes (request_id, therapist_id, body, updated_at)
  values (p_request_id, me, v_body, v_at)
  on conflict (request_id, therapist_id) do update
  set body = excluded.body, updated_at = excluded.updated_at;
  return v_at;
end;
$$;

-- The running note about a client, found from any session with them.
create or replace function public.therapist_save_client_note(p_request_id uuid, p_body text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_client uuid;
  v_body text := coalesce(p_body, '');
  v_at timestamptz := now();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select r.user_id into v_client
    from public.therapy_requests r
   where r.id = p_request_id and r.therapist_id = me;
  if v_client is null then
    raise exception 'That client isn’t one of yours.' using errcode = 'P0002';
  end if;
  if length(v_body) > 20000 then
    raise exception 'That note is too long to save. Shorten it to 20,000 characters.'
      using errcode = '22023';
  end if;
  if trim(v_body) = '' then
    delete from public.therapist_client_notes c
     where c.therapist_id = me and c.client_id = v_client;
    return null;
  end if;
  insert into public.therapist_client_notes (therapist_id, client_id, body, updated_at)
  values (me, v_client, v_body, v_at)
  on conflict (therapist_id, client_id) do update
  set body = excluded.body, updated_at = excluded.updated_at;
  return v_at;
end;
$$;

-- ── 5. Documents: renewed licences and insurance ─────────────────────

alter table public.therapists
  add column if not exists insurance_expires_on date;

create table if not exists public.therapist_documents (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  kind text not null check (kind in ('licence', 'insurance')),
  path text not null check (length(path) <= 300),
  number text check (length(number) <= 80),
  issuer text check (length(issuer) <= 160),
  expires_on date,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  review_note text check (length(review_note) <= 500),
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.therapist_documents enable row level security;
create index if not exists therapist_documents_idx
  on public.therapist_documents (therapist_id, created_at desc);
create index if not exists therapist_documents_pending_idx
  on public.therapist_documents (created_at) where status = 'pending';

-- The file is already in therapist-kyc under the therapist's own folder
-- (kyc_file_ok, 0029): they can add files there but never read them back.
create or replace function public.therapist_submit_document(
  p_kind text,
  p_path text,
  p_expires_on date,
  p_number text default null,
  p_issuer text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_id uuid;
  v_name text;
  v_email text;
  v_what text := case p_kind when 'licence' then 'licence' else 'insurance certificate' end;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('licence', 'insurance') then
    raise exception 'Choose what the document is.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_path) then
    raise exception 'Upload the document from this page.' using errcode = '22023';
  end if;
  if p_expires_on is null or p_expires_on <= current_date then
    raise exception 'Enter the date it expires. It has to be in the future.' using errcode = '22023';
  end if;
  if (select count(*) from public.therapist_documents d
       where d.therapist_id = me and d.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'You’ve sent several documents today. Message the care team if something’s wrong.'
      using errcode = '22023';
  end if;

  -- A newer upload replaces one still waiting to be checked.
  update public.therapist_documents d
     set status = 'rejected', review_note = 'Replaced by a newer upload.', reviewed_at = now()
   where d.therapist_id = me and d.kind = p_kind and d.status = 'pending';

  insert into public.therapist_documents (therapist_id, kind, path, number, issuer, expires_on)
  values (me, p_kind, p_path,
          nullif(left(trim(coalesce(p_number, '')), 80), ''),
          nullif(left(trim(coalesce(p_issuer, '')), 160), ''),
          p_expires_on)
  returning id into v_id;

  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = me;
  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    'To check: ' || v_what || ' from ' || coalesce(v_name, 'a therapist'),
    'A ' || v_what || ' to check',
    coalesce(v_name, 'A therapist') || ' uploaded a ' || v_what || ' from their workspace.',
    'What they sent',
    jsonb_build_array(
      jsonb_build_array('Number', nullif(trim(coalesce(p_number, '')), '')),
      jsonb_build_array('Issued by', nullif(trim(coalesce(p_issuer, '')), '')),
      jsonb_build_array('Expires', to_char(p_expires_on, 'FMDD Mon YYYY'))
    ),
    'Open it on the admin page, under Therapy → Documents, check it with whoever issued it, then accept it or send it back.',
    null,
    'therapist-document/' || v_id
  );
  return v_id;
end;
$$;

create or replace function public.admin_list_therapist_documents(p_status text default 'pending')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'therapist_id', d.therapist_id, 'full_name', t.full_name, 'email', ta.email,
    'kind', d.kind, 'path', d.path, 'number', d.number, 'issuer', d.issuer,
    'expires_on', d.expires_on, 'status', d.status, 'review_note', d.review_note,
    'reviewed_by', d.reviewed_by, 'reviewed_at', d.reviewed_at, 'created_at', d.created_at,
    'current_licence_expires_on', t.licence_expires_on,
    'current_insurance_expires_on', t.insurance_expires_on
  ) order by d.created_at desc), '[]'::jsonb)
  into result
  from public.therapist_documents d
  join public.therapists t on t.id = d.therapist_id
  left join public.therapist_accounts ta on ta.therapist_id = d.therapist_id
  where p_status is null or d.status = p_status;
  return result;
end;
$$;

-- Accepting a licence moves the therapist's expiry date; accepting
-- insurance records when that runs out. Either way the therapist is told.
create or replace function public.admin_review_therapist_document(
  p_id uuid,
  p_accept boolean,
  p_note text default null,
  p_expires_on date default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  doc public.therapist_documents%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note, '')), 500), '');
  v_expires date;
  v_name text;
  v_email text;
  v_what text;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into doc from public.therapist_documents d where d.id = p_id for update;
  if not found then
    raise exception 'That document no longer exists.' using errcode = 'P0002';
  end if;
  if doc.status <> 'pending' then
    raise exception 'That document has already been checked.' using errcode = '22023';
  end if;
  if not coalesce(p_accept, false) and v_note is null then
    raise exception 'Say what’s wrong with it, so they can put it right.' using errcode = '22023';
  end if;
  v_expires := coalesce(p_expires_on, doc.expires_on);
  v_what := case doc.kind when 'licence' then 'licence' else 'insurance certificate' end;
  if coalesce(p_accept, false) and (v_expires is null or v_expires <= current_date) then
    raise exception 'Enter the date it expires. It has to be in the future, or send it back instead.'
      using errcode = '22023';
  end if;

  update public.therapist_documents
     set status = case when coalesce(p_accept, false) then 'accepted' else 'rejected' end,
         review_note = v_note, expires_on = v_expires,
         reviewed_by = public.current_user_email(), reviewed_at = now()
   where id = p_id;
  if coalesce(p_accept, false) and v_expires is not null then
    if doc.kind = 'licence' then
      update public.therapists set licence_expires_on = v_expires, updated_at = now()
       where id = doc.therapist_id;
    else
      update public.therapists set insurance_expires_on = v_expires, updated_at = now()
       where id = doc.therapist_id;
    end if;
  end if;

  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = doc.therapist_id;
  perform public.therapist_site_email(
    v_email,
    public.care_team_email(),
    case when coalesce(p_accept, false) then 'We’ve accepted your ' || v_what
         else 'About the ' || v_what || ' you sent' end,
    case when coalesce(p_accept, false) then 'Your ' || v_what || ' is accepted'
         else 'Your ' || v_what || ' needs another look' end,
    'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ', '
      || case when coalesce(p_accept, false)
           then 'the care team has checked the ' || v_what || ' you uploaded and accepted it.'
           else 'the care team couldn’t accept the ' || v_what || ' you uploaded.' end,
    case when coalesce(p_accept, false) then 'On your record' else 'What they said' end,
    jsonb_build_array(
      jsonb_build_array('Expires', case when coalesce(p_accept, false)
        then to_char(v_expires, 'FMDD Mon YYYY') end),
      jsonb_build_array('Note', v_note)
    ),
    case when coalesce(p_accept, false) then 'It shows in your workspace, under Settings:'
         else 'Upload a new one in your workspace, under Settings:' end,
    public.therapist_site_url() || '/settings/documents',
    'therapist-document/' || p_id || '/reviewed'
  );
end;
$$;

-- ── 6. What the workspace loads in one go ────────────────────────────

-- What this browser has read and seen, shared between a therapist's devices.
create table if not exists public.therapist_site_state (
  therapist_id uuid primary key references public.therapists (id) on delete cascade,
  state jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.therapist_site_state enable row level security;

create or replace function public.therapist_save_site_state(p_state jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' or length(p_state::text) > 100000 then
    raise exception 'That’s too much to remember.' using errcode = '22023';
  end if;
  insert into public.therapist_site_state (therapist_id, state, updated_at)
  values (me, p_state, now())
  on conflict (therapist_id) do update set state = excluded.state, updated_at = now();
end;
$$;

create or replace function public.therapist_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'availability', (
      select jsonb_build_object(
        'timezone', a.timezone, 'hours', a.hours, 'max_per_day', a.max_per_day,
        'notice_hours', a.notice_hours, 'taking_new_clients', a.taking_new_clients,
        'updated_at', a.updated_at)
      from public.therapist_availability a where a.therapist_id = me),
    'time_off', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'starts_on', o.starts_on, 'ends_on', o.ends_on, 'note', o.note)
        order by o.starts_on)
      from public.therapist_time_off o
      where o.therapist_id = me and o.ends_on >= current_date - 31), '[]'::jsonb),
    'payout', (
      select jsonb_build_object(
        'method', p.method, 'account_name', p.account_name,
        'summary', public.therapist_payout_summary(p.method, p.details),
        'updated_at', p.updated_at)
      from public.therapist_payout_details p where p.therapist_id = me),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'kind', d.kind, 'number', d.number, 'issuer', d.issuer,
        'expires_on', d.expires_on, 'status', d.status, 'review_note', d.review_note,
        'created_at', d.created_at, 'reviewed_at', d.reviewed_at)
        order by d.created_at desc)
      from (
        select * from public.therapist_documents x
        where x.therapist_id = me order by x.created_at desc limit 20
      ) d), '[]'::jsonb),
    'insurance_expires_on', (
      select t.insurance_expires_on from public.therapists t where t.id = me),
    -- From three ratings up, as clients see it, so no one rating shows.
    'rating', (
      select jsonb_build_object('average', round(avg(rt.rating)::numeric, 1), 'count', count(*))
      from public.therapy_ratings rt
      join public.therapy_requests r on r.id = rt.request_id
      where rt.author_role = 'client' and r.therapist_id = me
      having count(*) >= 3),
    'state', coalesce((
      select s.state from public.therapist_site_state s where s.therapist_id = me), '{}'::jsonb),
    'server_time', now()
  );
end;
$$;

-- The country a session's client told us they're in, for the therapist
-- to know which emergency services to call. Nothing else about them.
create or replace function public.therapist_session_client_country(p_request_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_country text;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select coalesce(c.country_code, r.pricing_country) into v_country
    from public.therapy_requests r
    left join public.therapy_client_countries c on c.user_id = r.user_id
   where r.id = p_request_id and r.therapist_id = me;
  return nullif(v_country, '*');
end;
$$;

-- ── 7. Rules the site already promised ───────────────────────────────

-- As in 0032, plus: no new session for a therapist whose licence has
-- expired. Only a new booking or a change of therapist is checked, so
-- sessions already booked carry on.
create or replace function public.therapy_requests_agreement_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_name text;
  v_licence date;
begin
  if new.status = 'confirmed' and new.therapist_id is not null
     and (old.status is distinct from 'confirmed'
          or old.therapist_id is distinct from new.therapist_id) then
    select ta.email, t.full_name, t.licence_expires_on into v_email, v_name, v_licence
      from public.therapists t
      left join public.therapist_accounts ta on ta.therapist_id = t.id
     where t.id = new.therapist_id;
    if v_email is null or public.therapist_accepted_agreement(v_email) is null then
      raise exception '% hasn’t accepted the therapist agreement yet, so they can’t be given sessions. Ask them to sign in at therapists.mindpillars.app and accept it.',
        coalesce(v_name, 'This therapist') using errcode = 'P0001';
    end if;
    if v_licence is not null and v_licence < current_date then
      raise exception '%’s licence expired on %, so they can’t be given new sessions. Ask them to upload the renewed one at therapists.mindpillars.app, under Settings.',
        coalesce(v_name, 'This therapist'), to_char(v_licence, 'FMDD Mon YYYY')
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

-- When each side of a session really began, and what's been sent about it,
-- kept apart from therapy_requests so writing here fires none of its triggers.
create table if not exists public.therapist_session_marks (
  request_id uuid primary key references public.therapy_requests (id) on delete cascade,
  therapist_started_at timestamptz,
  day_reminder_for timestamptz
);
alter table public.therapist_session_marks enable row level security;

-- The therapist pressed "Start the session": they're in the call, sharing
-- sound and video, not just in the waiting room.
create or replace function public.therapist_session_started(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.therapy_requests r
    where r.id = p_request_id and r.therapist_id = me and r.status = 'confirmed'
  ) then
    return;
  end if;
  insert into public.therapist_session_marks (request_id, therapist_started_at)
  values (p_request_id, now())
  on conflict (request_id) do update
  set therapist_started_at = coalesce(public.therapist_session_marks.therapist_started_at, now());
end;
$$;

-- The agreement (3.6): joining more than 15 minutes late means the client
-- is refunded and the session isn't paid. Deciding that stays with the care
-- team, so they're told the moment it happens.
create or replace function public.notify_therapist_late_join()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_email text;
  v_late integer;
begin
  if new.scheduled_at is null
     or new.therapist_joined_at <= new.scheduled_at + interval '15 minutes' then
    return new;
  end if;
  v_late := ceil(extract(epoch from (new.therapist_joined_at - new.scheduled_at)) / 60)::integer;
  select t.full_name, ta.email into v_name, v_email
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = new.therapist_id;
  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    'Joined ' || v_late || ' minutes late — ' || coalesce(v_name, 'a therapist'),
    'A therapist joined late',
    coalesce(v_name, 'A therapist') || ' opened the call ' || v_late
      || ' minutes after the session was due to start.',
    'Session',
    jsonb_build_array(
      jsonb_build_array('When', public.email_session_time(new.scheduled_at)),
      jsonb_build_array('Client joined', case when new.client_joined_at is null then 'Not yet'
        else to_char(new.client_joined_at at time zone 'Africa/Nairobi', 'HH24:MI') || ' Nairobi time' end)
    ),
    'The agreement (3.6) says a session joined more than 15 minutes late is refunded and not paid. Nothing has been changed automatically: decide with the client and the therapist what happened.',
    null,
    'therapist-late/' || new.id
  );
  return new;
exception when others then
  raise warning 'late-join notice for session % failed: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists therapy_therapist_late_join on public.therapy_requests;
create trigger therapy_therapist_late_join
  after update of therapist_joined_at on public.therapy_requests
  for each row
  when (old.therapist_joined_at is null and new.therapist_joined_at is not null)
  execute function public.notify_therapist_late_join();

-- ── 8. Reminders ─────────────────────────────────────────────────────

-- Every 15 minutes: each confirmed session starting within the next day
-- gets one email to its therapist. A session booked in the last 6 hours is
-- left alone: they've just had the "New session" email.
create or replace function public.send_therapist_day_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  sent integer := 0;
  v_name text;
  v_email text;
  v_client text;
begin
  for r in
    select q.id, q.therapist_id, q.user_id, q.scheduled_at, q.duration_minutes, q.payment_status
    from public.therapy_requests q
    where q.status = 'confirmed'
      and q.therapist_id is not null
      and q.scheduled_at > now() + interval '12 hours'
      and q.scheduled_at <= now() + interval '24 hours'
      and coalesce(q.confirmed_at, q.created_at) < now() - interval '6 hours'
      and not exists (
        select 1 from public.therapist_session_marks m
        where m.request_id = q.id and m.day_reminder_for = q.scheduled_at)
    order by q.scheduled_at
    limit 200
  loop
    begin
      insert into public.therapist_session_marks (request_id, day_reminder_for)
      values (r.id, r.scheduled_at)
      on conflict (request_id) do update set day_reminder_for = excluded.day_reminder_for;

      select t.full_name, ta.email into v_name, v_email
        from public.therapists t
        left join public.therapist_accounts ta on ta.therapist_id = t.id
       where t.id = r.therapist_id;
      if v_email is null then
        continue;
      end if;
      v_client := coalesce(public.therapy_client_first_name(r.user_id), 'your client');
      perform public.therapist_site_email(
        v_email,
        public.care_team_email(),
        'Tomorrow: your session with ' || v_client,
        'Your session with ' || v_client,
        'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ', a reminder of your session with '
          || v_client || ' in the next day.',
        'Session',
        jsonb_build_array(
          jsonb_build_array('When', public.therapist_local_time(r.therapist_id, r.scheduled_at)),
          jsonb_build_array('Length', r.duration_minutes || ' minutes'),
          jsonb_build_array('Payment', case when r.payment_status = 'unpaid'
            then 'Not paid yet. The call opens once they have.' end)
        ),
        'The waiting room opens 10 minutes before. Can’t make it? Tell the care team now, from the session’s page:',
        public.therapist_site_url() || '/sessions/' || r.id,
        'therapist-day-reminder/' || r.id || '/' || extract(epoch from r.scheduled_at)::bigint
      );
      sent := sent + 1;
    exception when others then
      raise warning 'day reminder for session % failed: %', r.id, sqlerrm;
    end;
  end loop;
  return sent;
end;
$$;

-- Once a day: licences and insurance about to run out, and the day after
-- they have. The care team hears about the ones that have lapsed.
create or replace function public.send_therapist_document_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  sent integer := 0;
  v_days integer;
  v_what text;
  v_on date;
  v_first text;
begin
  for r in
    select t.id, t.full_name, ta.email, x.kind, x.expires_on
    from public.therapists t
    join public.therapist_accounts ta on ta.therapist_id = t.id
    cross join lateral (values
      ('licence', t.licence_expires_on),
      ('insurance', t.insurance_expires_on)) as x(kind, expires_on)
    where t.active and x.expires_on is not null
  loop
    begin
      v_days := r.expires_on - current_date;
      v_on := r.expires_on;
      v_what := case r.kind when 'licence' then 'licence' else 'insurance' end;
      v_first := split_part(coalesce(r.full_name, ''), ' ', 1);
      if v_days in (60, 30, 14, 7, 1) then
        perform public.therapist_site_email(
          r.email,
          public.care_team_email(),
          'Your ' || v_what || ' expires on ' || to_char(v_on, 'FMDD Mon YYYY'),
          'Your ' || v_what || ' expires soon',
          'Hi ' || v_first || ', your ' || v_what || ' runs out in ' || v_days || ' day'
            || case when v_days = 1 then '' else 's' end || '.'
            || case when r.kind = 'licence'
                 then ' Once it has, we can’t book new sessions with you until we have the renewed one.'
                 else '' end,
          'On your record',
          jsonb_build_array(jsonb_build_array('Expires', to_char(v_on, 'FMDD Mon YYYY'))),
          'Upload the renewed one in your workspace, under Settings:',
          public.therapist_site_url() || '/settings/documents',
          'therapist-doc-reminder/' || r.id || '/' || r.kind || '/' || v_on || '/' || v_days
        );
        sent := sent + 1;
      elsif v_days = -1 then
        perform public.therapist_site_email(
          r.email,
          public.care_team_email(),
          'Your ' || v_what || ' has expired',
          'Your ' || v_what || ' has expired',
          'Hi ' || v_first || ', your ' || v_what || ' ran out on ' || to_char(v_on, 'FMDD Mon YYYY') || '.'
            || case when r.kind = 'licence'
                 then ' We can’t book new sessions with you until we have the renewed one. Sessions already booked aren’t affected.'
                 else ' The agreement (2.5) asks you to keep it current.' end,
          null, null,
          'Upload the renewed one in your workspace, under Settings:',
          public.therapist_site_url() || '/settings/documents',
          'therapist-doc-reminder/' || r.id || '/' || r.kind || '/' || v_on || '/expired'
        );
        perform public.therapist_site_email(
          public.care_team_email(),
          r.email,
          coalesce(r.full_name, 'A therapist') || '’s ' || v_what || ' has expired',
          'A ' || v_what || ' has expired',
          coalesce(r.full_name, 'A therapist') || '’s ' || v_what || ' ran out on '
            || to_char(v_on, 'FMDD Mon YYYY') || ', and they’ve been emailed.'
            || case when r.kind = 'licence'
                 then ' They can’t be given new sessions until a renewed one is accepted.' else '' end,
          null, null, null, null,
          'therapist-doc-reminder/' || r.id || '/' || r.kind || '/' || v_on || '/expired/care'
        );
        sent := sent + 1;
      end if;
    exception when others then
      raise warning 'document reminder for therapist % failed: %', r.id, sqlerrm;
    end;
  end loop;
  return sent;
end;
$$;

select cron.unschedule(jobid)
  from cron.job where jobname in ('therapist-day-reminders', 'therapist-document-reminders');
select cron.schedule(
  'therapist-day-reminders',
  '*/15 * * * *',
  $$select public.send_therapist_day_reminders()$$
);
select cron.schedule(
  'therapist-document-reminders',
  '10 5 * * *',
  $$select public.send_therapist_document_reminders()$$
);

-- ── 9. Faults on the therapist site ──────────────────────────────────

create table if not exists public.site_errors (
  fingerprint text primary key,
  site text not null default 'therapists',
  message text not null,
  stack text,
  url text,
  release text,
  user_agent text,
  context jsonb not null default '{}',
  user_email text,
  count integer not null default 1,
  status text not null default 'new' check (status in ('new', 'seen', 'fixed', 'ignored')),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  emailed_at timestamptz
);
alter table public.site_errors enable row level security;
create index if not exists site_errors_recent_idx on public.site_errors (last_seen_at desc);

-- Called by the site, signed in or not, when something fails in a browser.
-- Never raises: reporting a fault mustn't cause another.
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
  v_fp text;
  v_status text;
  v_tell boolean := false;
begin
  if v_message = '' then
    return;
  end if;
  if jsonb_typeof(v_context) <> 'object' or length(v_context::text) > 2000 then
    v_context := '{}'::jsonb;
  end if;
  v_agent := left(coalesce(v_context ->> 'agent', ''), 300);
  -- Ids and numbers differ between two reports of the same fault.
  v_fp := md5(regexp_replace(v_message,
            '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9]+', '#', 'g')
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
    -- The log holds 2,000 faults. When it's full, the ones seen longest ago
    -- make room, so it can't be filled up and silenced.
    if (select count(*) from public.site_errors) >= 2000 then
      delete from public.site_errors e
       where e.fingerprint in (
         select o.fingerprint from public.site_errors o order by o.last_seen_at limit 100);
    end if;
    insert into public.site_errors
      (fingerprint, message, stack, url, release, user_agent, context, user_email)
    values (v_fp, v_message, nullif(v_stack, ''), nullif(v_url, ''), nullif(v_release, ''),
            nullif(v_agent, ''), v_context - 'agent', v_email)
    on conflict (fingerprint) do update
      set count = public.site_errors.count + 1, last_seen_at = now();
    v_tell := true;
  end if;

  if v_tell and (
    select count(*) from public.site_errors e where e.emailed_at > now() - interval '1 hour'
  ) < 6 then
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

create or replace function public.admin_list_site_errors(p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.last_seen_at desc), '[]'::jsonb) into result
  from (
    select e.* from public.site_errors e
    where p_status is null or e.status = p_status
    order by e.last_seen_at desc
    limit 300
  ) q;
  return result;
end;
$$;

create or replace function public.admin_set_site_error_status(p_fingerprint text, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('new', 'seen', 'fixed', 'ignored') then
    raise exception 'Choose new, seen, fixed or ignored.' using errcode = '22023';
  end if;
  update public.site_errors set status = p_status where fingerprint = p_fingerprint;
end;
$$;

-- ── 10. The agreement, version of 15 November 2026 ───────────────────

-- Keep in step with AGREEMENT_VERSION in the therapist site
-- (src/lib/agreement.ts). Changing it asks everyone to sign again.
create or replace function public.therapist_agreement_version()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-11-15';
$$;

-- Emails every therapist who hasn't signed the current version, once per
-- version. Run it from the SQL editor when you're ready:
--   select public.notify_agreement_changed();
create or replace function public.notify_agreement_changed()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  sent integer := 0;
begin
  for r in
    select t.id, t.full_name, ta.email
    from public.therapists t
    join public.therapist_accounts ta on ta.therapist_id = t.id
    where t.active and public.therapist_accepted_agreement(ta.email) is null
  loop
    perform public.therapist_site_email(
      r.email,
      public.care_team_email(),
      'Please sign the updated therapist agreement',
      'The therapist agreement has been updated',
      'Hi ' || split_part(coalesce(r.full_name, ''), ' ', 1)
        || ', we’ve updated the therapist agreement. It now sets out in full what’s expected around money, gifts and contact with clients outside the platform, and how your payout details, notes and documents are handled.',
      'What to do',
      jsonb_build_array(
        jsonb_build_array('1', 'Sign in to your workspace'),
        jsonb_build_array('2', 'Read the agreement and sign it at the bottom'),
        jsonb_build_array('Until then', 'We can’t book new sessions with you. Sessions already booked aren’t affected.')
      ),
      'Read and sign it here:',
      public.therapist_site_url() || '/agreement',
      'therapist-agreement/' || public.therapist_agreement_version() || '/' || md5(r.email)
    );
    sent := sent + 1;
  end loop;
  return sent;
end;
$$;

-- ── 11. The 10-minute reminder points at the waiting room ────────────

-- send_session_reminders: as in 0010_session_notifications.sql, except that
-- the therapist's email links to their waiting room on the therapist site
-- instead of only naming the app.
create or replace function public.send_session_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  strong constant text := '<strong style="font-weight:600;color:#191919;">';
  r public.therapy_requests%rowtype;
  sent integer := 0;
  minutes integer;
  starts text;
  client_email text;
  client_first text;
  therapist_name text;
  therapist_email text;
  when_text text;
  unpaid boolean;
  event_key text;
begin
  for r in
    update public.therapy_requests
    set reminder_sent_at = now()
    where status = 'confirmed'
      and reminder_sent_at is null
      and scheduled_at <= now() + interval '10 minutes'
      and scheduled_at > now() - interval '5 minutes'
    returning *
  loop
    begin
      minutes := greatest(1, ceil(extract(epoch from (r.scheduled_at - now())) / 60)::integer);
      starts := case
        when r.scheduled_at <= now() then 'is starting now'
        when minutes = 1 then 'starts in 1 minute'
        else 'starts in ' || minutes || ' minutes'
      end;
      select u.email::text into client_email
        from auth.users u where u.id = r.user_id;
      client_first := public.therapy_client_first_name(r.user_id);
      select t.full_name, ta.email
        into therapist_name, therapist_email
        from public.therapists t
        left join public.therapist_accounts ta on ta.therapist_id = t.id
        where t.id = r.therapist_id;
      when_text := public.email_session_time(r.scheduled_at);
      unpaid := r.payment_status = 'unpaid';
      event_key := 'therapy-session/' || r.id || '/reminder/'
        || extract(epoch from r.scheduled_at)::bigint;

      perform public.send_app_email(
        client_email,
        care_team,
        'Your session ' || starts,
        public.email_layout(
          public.email_escape('With ' || coalesce(therapist_name, 'your therapist')
            || ' · ' || when_text),
          'Your session ' || starts,
          'Hi ' || public.email_escape(coalesce(client_first, 'there'))
            || ', your session with ' || strong
            || public.email_escape(coalesce(therapist_name, 'your therapist'))
            || '</strong> ' || starts || '.',
          public.email_box('#F3F6FC', 'How to join',
            '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
            || case when unpaid
               then 'It hasn’t been paid for yet — pay in the app first, and the '
                 || 'Join button unlocks straight away. '
               else '' end
            || 'Open the app, go to ' || strong || 'Talk to a therapist</strong> '
            || 'and tap ' || strong || 'Join session</strong>. Find a quiet, '
            || 'private spot — you’ll need your camera and microphone.</div>'),
          'Session time: ' || public.email_escape(when_text)
            || '. Can’t make it? Just reply to this email.'
        ),
        'Hi ' || coalesce(client_first, 'there') || ','
          || E'\n\n'
          || 'Your session with ' || coalesce(therapist_name, 'your therapist')
          || ' ' || starts || ' (' || when_text || ').'
          || E'\n\n'
          || case when unpaid
             then 'It hasn’t been paid for yet — pay in the app first, and the '
               || 'Join button unlocks straight away.' || E'\n\n'
             else '' end
          || 'Open the app, go to Talk to a therapist and tap Join session.'
          || E'\n\n' || '— Δεν είσαι μόνος',
        event_key || '/client'
      );

      perform public.send_app_email(
        therapist_email,
        care_team,
        'Session with ' || coalesce(client_first, 'your client') || ' ' || starts,
        public.email_layout(
          public.email_escape(when_text),
          'Your session ' || starts,
          'Your session with ' || strong
            || public.email_escape(coalesce(client_first, 'your client'))
            || '</strong> ' || starts || '.',
          public.email_box('#F3F6FC', 'How to join',
            '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
            || case when unpaid
               then 'The client hasn’t paid yet — the call opens once they do. '
               else '' end
            || 'Open your waiting room at <a href="https://therapists.mindpillars.app/sessions/'
            || r.id || '/room">therapists.mindpillars.app</a>, or in the app under '
            || strong || 'Settings → My therapy sessions</strong>.</div>'),
          'Session time: ' || public.email_escape(when_text) || '.'
        ),
        'Your session with ' || coalesce(client_first, 'your client') || ' '
          || starts || ' (' || when_text || ').'
          || E'\n\n'
          || case when unpaid
             then 'The client hasn’t paid yet — the call opens once they do.' || E'\n\n'
             else '' end
          || 'Open your waiting room: https://therapists.mindpillars.app/sessions/'
          || r.id || '/room (or in the app, under Settings → My therapy sessions).',
        event_key || '/therapist'
      );

      perform public.queue_session_notifications(r, 'session_reminder');
      sent := sent + 1;
    exception when others then
      raise warning 'reminder for session % failed: %', r.id, sqlerrm;
    end;
  end loop;
  return sent;
end;
$$;

-- ── Who can call what ────────────────────────────────────────────────

-- Used only inside the functions above, by cron, or from the SQL editor.
revoke execute on function public.care_team_email() from public, anon, authenticated;
revoke execute on function public.therapist_site_url() from public, anon, authenticated;
revoke execute on function public.therapist_site_email(text, text, text, text, text, text, jsonb, text, text, text) from public, anon, authenticated;
revoke execute on function public.therapist_hours_ok(jsonb) from public, anon, authenticated;
revoke execute on function public.therapist_local_time(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.therapist_ticket_kind_label(text) from public, anon, authenticated;
revoke execute on function public.therapist_payout_summary(text, jsonb) from public, anon, authenticated;
revoke execute on function public.notify_therapist_late_join() from public, anon, authenticated;
revoke execute on function public.send_therapist_day_reminders() from public, anon, authenticated;
revoke execute on function public.send_therapist_document_reminders() from public, anon, authenticated;
revoke execute on function public.notify_agreement_changed() from public, anon, authenticated;
revoke execute on function public.therapy_requests_agreement_check() from public, anon, authenticated;
revoke execute on function public.send_session_reminders() from public, anon, authenticated;

-- Therapists (each function checks who is calling).
revoke execute on function public.therapist_set_availability(text, jsonb, integer, integer, boolean) from public, anon;
revoke execute on function public.therapist_add_time_off(date, date, text) from public, anon;
revoke execute on function public.therapist_remove_time_off(uuid) from public, anon;
revoke execute on function public.therapist_open_ticket(text, text, text, uuid, jsonb) from public, anon;
revoke execute on function public.therapist_reply_ticket(uuid, text) from public, anon;
revoke execute on function public.therapist_close_ticket(uuid) from public, anon;
revoke execute on function public.therapist_list_tickets() from public, anon;
revoke execute on function public.therapist_save_payout_details(text, text, jsonb) from public, anon;
revoke execute on function public.therapist_list_notes() from public, anon;
revoke execute on function public.therapist_save_session_note(uuid, text) from public, anon;
revoke execute on function public.therapist_save_client_note(uuid, text) from public, anon;
revoke execute on function public.therapist_submit_document(text, text, date, text, text) from public, anon;
revoke execute on function public.therapist_save_site_state(jsonb) from public, anon;
revoke execute on function public.therapist_workspace() from public, anon;
revoke execute on function public.therapist_session_client_country(uuid) from public, anon;
revoke execute on function public.therapist_session_started(uuid) from public, anon;
grant execute on function public.therapist_set_availability(text, jsonb, integer, integer, boolean) to authenticated;
grant execute on function public.therapist_add_time_off(date, date, text) to authenticated;
grant execute on function public.therapist_remove_time_off(uuid) to authenticated;
grant execute on function public.therapist_open_ticket(text, text, text, uuid, jsonb) to authenticated;
grant execute on function public.therapist_reply_ticket(uuid, text) to authenticated;
grant execute on function public.therapist_close_ticket(uuid) to authenticated;
grant execute on function public.therapist_list_tickets() to authenticated;
grant execute on function public.therapist_save_payout_details(text, text, jsonb) to authenticated;
grant execute on function public.therapist_list_notes() to authenticated;
grant execute on function public.therapist_save_session_note(uuid, text) to authenticated;
grant execute on function public.therapist_save_client_note(uuid, text) to authenticated;
grant execute on function public.therapist_submit_document(text, text, date, text, text) to authenticated;
grant execute on function public.therapist_save_site_state(jsonb) to authenticated;
grant execute on function public.therapist_workspace() to authenticated;
grant execute on function public.therapist_session_client_country(uuid) to authenticated;
grant execute on function public.therapist_session_started(uuid) to authenticated;

-- The care team (each function checks is_admin()).
revoke execute on function public.admin_check_therapist_slot(uuid, timestamptz, integer) from public, anon;
revoke execute on function public.admin_list_therapist_availability() from public, anon;
revoke execute on function public.admin_list_therapist_tickets(text) from public, anon;
revoke execute on function public.admin_reply_therapist_ticket(uuid, text, boolean) from public, anon;
revoke execute on function public.admin_list_therapist_payout_details() from public, anon;
revoke execute on function public.admin_list_therapist_documents(text) from public, anon;
revoke execute on function public.admin_review_therapist_document(uuid, boolean, text, date) from public, anon;
revoke execute on function public.admin_list_site_errors(text) from public, anon;
revoke execute on function public.admin_set_site_error_status(text, text) from public, anon;
grant execute on function public.admin_check_therapist_slot(uuid, timestamptz, integer) to authenticated;
grant execute on function public.admin_list_therapist_availability() to authenticated;
grant execute on function public.admin_list_therapist_tickets(text) to authenticated;
grant execute on function public.admin_reply_therapist_ticket(uuid, text, boolean) to authenticated;
grant execute on function public.admin_list_therapist_payout_details() to authenticated;
grant execute on function public.admin_list_therapist_documents(text) to authenticated;
grant execute on function public.admin_review_therapist_document(uuid, boolean, text, date) to authenticated;
grant execute on function public.admin_list_site_errors(text) to authenticated;
grant execute on function public.admin_set_site_error_status(text, text) to authenticated;

-- Anyone, signed in or not: a fault can happen on the sign-in page too.
revoke execute on function public.report_site_error(text, text, text, text, jsonb) from public;
grant execute on function public.report_site_error(text, text, text, text, jsonb) to anon, authenticated;

commit;
