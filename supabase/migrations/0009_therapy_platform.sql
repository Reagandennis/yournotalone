-- The therapy platform: therapists, matching, in-app video sessions,
-- per-session payments and two-way ratings.
--
-- Builds on 0003 (therapy_requests) and 0008 (the Resend email helpers).
-- Run in Supabase dashboard → SQL Editor, or from the repo:
--   supabase db query --linked -f supabase/migrations/0009_therapy_platform.sql
-- Safe to re-run.
--
-- Who can do what
--   Clients     request sessions, see their own, cancel one they haven't
--               paid for, pay, join the call, rate it once it's finished,
--               and read their therapist's profile.
--   Therapists  sign in with the email the care team registered for them.
--               They see only sessions assigned to them, join the call,
--               finish a session with a note for the client, and rate the
--               client. That rating is private to them and the care team.
--   Admins      the emails in public.admins. They see everything, manage
--               therapists, match requests and record payments.
--
-- Roles come from the signed-in user's *confirmed* email on every call. An
-- invite therefore works before the account exists, and nobody gets a role
-- by signing up with an address they can't receive mail at.
--
-- Pricing: someone's first session is free; every session after that is
-- $20, paid in the app before the call can be joined. The server decides
-- both — nothing the app sends can change them.

create extension if not exists pg_net;

-- ── Roles ────────────────────────────────────────────────────────────

create table if not exists public.admins (
  email text primary key check (email = lower(trim(email))),
  created_at timestamptz not null default now()
);

alter table public.admins enable row level security;
-- No policies: only the security-definer functions below read it.

insert into public.admins (email)
values ('reagan.e.owiti@gmail.com'), ('reaganprezzo@gmail.com')
on conflict (email) do nothing;

create table if not exists public.therapists (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  title text check (length(title) <= 120),
  credentials text check (length(credentials) <= 200),
  bio text check (length(bio) <= 2000),
  specialties text[] not null default '{}',
  languages text[] not null default '{}',
  years_experience smallint check (years_experience between 0 and 70),
  photo_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.therapists enable row level security;

-- The sign-in email lives apart from the profile, so clients — who can read
-- profiles — never see it.
create table if not exists public.therapist_accounts (
  therapist_id uuid primary key references public.therapists (id) on delete cascade,
  email text not null unique check (email = lower(trim(email))),
  created_at timestamptz not null default now()
);

alter table public.therapist_accounts enable row level security;

create or replace function public.current_user_email()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select lower(u.email)
  from auth.users u
  where u.id = auth.uid() and u.email_confirmed_at is not null;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins a where a.email = public.current_user_email()
  );
$$;

create or replace function public.current_therapist_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ta.therapist_id
  from public.therapist_accounts ta
  where ta.email = public.current_user_email();
$$;

drop policy if exists "Signed-in users read therapist profiles" on public.therapists;
create policy "Signed-in users read therapist profiles"
  on public.therapists for select to authenticated
  using (true);

drop policy if exists "Therapists and admins read sign-in emails" on public.therapist_accounts;
create policy "Therapists and admins read sign-in emails"
  on public.therapist_accounts for select to authenticated
  using (
    therapist_id = (select public.current_therapist_id())
    or (select public.is_admin())
  );

-- ── Sessions ─────────────────────────────────────────────────────────

create or replace function public.therapy_session_price_cents()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 2000;
$$;

alter table public.therapy_requests
  add column if not exists therapist_id uuid references public.therapists (id),
  add column if not exists duration_minutes smallint not null default 50
    check (duration_minutes between 15 and 180),
  add column if not exists price_cents integer not null default 0
    check (price_cents >= 0),
  add column if not exists currency text not null default 'USD',
  add column if not exists payment_status text not null default 'not_required'
    check (payment_status in ('not_required', 'unpaid', 'paid', 'waived')),
  add column if not exists payment_ref text unique,
  add column if not exists paid_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists client_summary text
    check (length(client_summary) <= 4000);

-- Requests made before pricing existed: anything open that wasn't the free
-- first session is now a paid one.
update public.therapy_requests
set price_cents = public.therapy_session_price_cents(),
    payment_status = 'unpaid'
where not is_free_session
  and payment_status = 'not_required'
  and status in ('pending', 'confirmed');

alter table public.therapy_requests
  drop constraint if exists therapy_requests_matched_check;
alter table public.therapy_requests
  add constraint therapy_requests_matched_check
  check (
    status not in ('confirmed', 'completed')
    or (therapist_id is not null and scheduled_at is not null)
  );

-- One free session per person, even if two requests race each other.
create unique index if not exists therapy_requests_one_free_session_idx
  on public.therapy_requests (user_id)
  where is_free_session and status <> 'cancelled';

create index if not exists therapy_requests_therapist_schedule_idx
  on public.therapy_requests (therapist_id, scheduled_at)
  where therapist_id is not null;

-- The app may only send the content of a request. Everything else — status,
-- price, whether it's the free one — is decided here. Security invoker on
-- purpose: current_user is the caller, so the security-definer functions
-- below (which run as the owner) and the dashboard pass straight through.
create or replace function public.therapy_requests_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.status := 'pending';
    new.therapist_id := null;
    new.scheduled_at := null;
    new.duration_minutes := 50;
    new.payment_ref := null;
    new.paid_at := null;
    new.confirmed_at := null;
    new.completed_at := null;
    new.cancelled_at := null;
    new.client_summary := null;
    new.created_at := now();
  end if;
  new.is_free_session := not exists (
    select 1 from public.therapy_requests r
    where r.user_id = new.user_id and r.status <> 'cancelled'
  );
  new.price_cents := case
    when new.is_free_session then 0
    else public.therapy_session_price_cents()
  end;
  new.currency := 'USD';
  new.payment_status := case
    when new.is_free_session then 'not_required'
    else 'unpaid'
  end;
  return new;
end;
$$;

-- From the app, the only change allowed is cancelling a session that hasn't
-- been paid for. A paid one goes through the care team, who can refund it.
create or replace function public.therapy_requests_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if new.status is distinct from 'cancelled'
     or old.status not in ('pending', 'confirmed')
     or old.payment_status = 'paid' then
    raise exception 'Only an unpaid session can be cancelled from the app.'
      using errcode = '42501';
  end if;
  new := old;
  new.status := 'cancelled';
  new.cancelled_at := now();
  return new;
end;
$$;

drop trigger if exists therapy_requests_before_insert on public.therapy_requests;
create trigger therapy_requests_before_insert
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_before_insert();

drop trigger if exists therapy_requests_before_update on public.therapy_requests;
create trigger therapy_requests_before_update
  before update on public.therapy_requests
  for each row execute function public.therapy_requests_before_update();

drop policy if exists "Users cancel own therapy requests" on public.therapy_requests;
create policy "Users cancel own therapy requests"
  on public.therapy_requests for update
  using (auth.uid() = user_id and status in ('pending', 'confirmed'))
  with check (auth.uid() = user_id and status = 'cancelled');

drop policy if exists "Therapists read assigned sessions" on public.therapy_requests;
create policy "Therapists read assigned sessions"
  on public.therapy_requests for select to authenticated
  using (
    therapist_id is not null
    and therapist_id = (select public.current_therapist_id())
  );

drop policy if exists "Admins read all therapy requests" on public.therapy_requests;
create policy "Admins read all therapy requests"
  on public.therapy_requests for select to authenticated
  using ((select public.is_admin()));

-- ── Ratings ──────────────────────────────────────────────────────────

create table if not exists public.therapy_ratings (
  request_id uuid not null references public.therapy_requests (id) on delete cascade,
  author_role text not null check (author_role in ('client', 'therapist')),
  author_id uuid references auth.users (id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  comment text check (length(comment) <= 1000),
  -- Therapist ratings only: no_show, late, safety_concern, follow_up.
  flags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (request_id, author_role)
);

alter table public.therapy_ratings enable row level security;

-- Written only through rate_therapy_session(). A therapist never reads a
-- client's individual rating, and a client never reads the therapist's.
drop policy if exists "People read ratings they wrote" on public.therapy_ratings;
create policy "People read ratings they wrote"
  on public.therapy_ratings for select to authenticated
  using (author_id = auth.uid() or (select public.is_admin()));

-- ── Therapist photos ─────────────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'therapist-photos',
  'therapist-photos',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists "Therapist photos are publicly readable" on storage.objects;
create policy "Therapist photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'therapist-photos');

drop policy if exists "Admins upload therapist photos" on storage.objects;
create policy "Admins upload therapist photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'therapist-photos' and (select public.is_admin()));

drop policy if exists "Admins update therapist photos" on storage.objects;
create policy "Admins update therapist photos"
  on storage.objects for update to authenticated
  using (bucket_id = 'therapist-photos' and (select public.is_admin()));

drop policy if exists "Admins delete therapist photos" on storage.objects;
create policy "Admins delete therapist photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'therapist-photos' and (select public.is_admin()));

-- ── Email ────────────────────────────────────────────────────────────

-- One email through Resend. Quietly does nothing until the API key is in
-- Vault, and never raises: an email must not undo a booking.
create or replace function public.send_app_email(
  p_to text,
  p_reply_to text,
  p_subject text,
  p_html text,
  p_text text,
  p_idempotency_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  api_key text;
  sender text;
begin
  if nullif(trim(p_to), '') is null then
    return;
  end if;
  select decrypted_secret into api_key
    from vault.decrypted_secrets where name = 'resend_api_key';
  if api_key is null then
    return;
  end if;
  select decrypted_secret into sender
    from vault.decrypted_secrets where name = 'resend_from';
  sender := coalesce(
    nullif(trim(sender), ''),
    'Den eisai monos <onboarding@resend.dev>'
  );
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || api_key,
      'Content-Type', 'application/json',
      'Idempotency-Key', p_idempotency_key
    ),
    body := jsonb_strip_nulls(jsonb_build_object(
      'from', sender,
      'to', jsonb_build_array(p_to),
      'reply_to', p_reply_to,
      'subject', p_subject,
      'html', p_html,
      'text', p_text
    )),
    timeout_milliseconds := 10000
  );
exception when others then
  raise warning 'email "%" failed: %', p_subject, sqlerrm;
end;
$$;

-- The care team works in Nairobi time; clients may not, so UTC rides along
-- and the emails point at the app, which shows their own time zone.
create or replace function public.email_session_time(t timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(t at time zone 'Africa/Nairobi', 'Dy FMDD Mon, HH24:MI')
    || ' Nairobi time (' || to_char(t at time zone 'UTC', 'HH24:MI') || ' UTC)';
$$;

create or replace function public.therapy_client_first_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(split_part(trim(regexp_replace(
    coalesce(u.raw_user_meta_data ->> 'full_name',
             u.raw_user_meta_data ->> 'name', ''),
    '\s+', ' ', 'g')), ' ', 1), '')
  from auth.users u
  where u.id = p_user_id;
$$;

-- Matched, moved, or cancelled after being matched: tell the client and the
-- therapist. The request email itself is still 0008's job.
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
      pay_client := 'This session is $' || (new.price_cents / 100)
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

drop trigger if exists therapy_session_notify on public.therapy_requests;
create trigger therapy_session_notify
  after update on public.therapy_requests
  for each row execute function public.notify_therapy_session_change();

create or replace function public.notify_therapist_invited()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  therapist_name text;
begin
  if tg_op = 'UPDATE' and new.email = old.email then
    return new;
  end if;
  select t.full_name into therapist_name
    from public.therapists t where t.id = new.therapist_id;
  perform public.send_app_email(
    new.email,
    care_team,
    'You’ve been added as a therapist',
    public.email_layout(
      'Sign in with this email to see your sessions.',
      'Welcome to the care team',
      'Hi ' || public.email_escape(split_part(coalesce(therapist_name, ''), ' ', 1))
        || ', you’ve been added as a therapist on Δεν είσαι μόνος.',
      public.email_box('#F6F6F6', 'Getting started',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Install the app and sign in with <strong style="font-weight:600;color:#191919;">'
        || public.email_escape(new.email) || '</strong> — with Google, or with a '
        || 'password and the confirmation email. Your sessions appear under '
        || '<strong style="font-weight:600;color:#191919;">Settings → My therapy sessions</strong>, '
        || 'and each one is a video call inside the app.</div>'),
      'Questions? Just reply to this email.'
    ),
    'Hi ' || split_part(coalesce(therapist_name, ''), ' ', 1) || ','
      || E'\n\n'
      || 'You’ve been added as a therapist on Δεν είσαι μόνος. Install the app and '
      || 'sign in with ' || new.email || ' (Google, or a password and the '
      || 'confirmation email). Your sessions appear under Settings → My therapy '
      || 'sessions, and each one is a video call inside the app.',
    'therapist-invite/' || new.therapist_id || '/' || md5(new.email)
  );
  return new;
end;
$$;

drop trigger if exists therapist_invite_notify on public.therapist_accounts;
create trigger therapist_invite_notify
  after insert or update of email on public.therapist_accounts
  for each row execute function public.notify_therapist_invited();

-- ── For the app ──────────────────────────────────────────────────────

create or replace function public.my_care_roles()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'is_admin', public.is_admin(),
    'therapist_id', t.id,
    'therapist_name', t.full_name
  )
  from (select public.current_therapist_id() as id) me
  left join public.therapists t on t.id = me.id;
$$;

-- Client ratings, averaged per therapist. Shown to clients only from three
-- ratings up, so a therapist can't work out what one person said.
create or replace function public.therapist_rating_summaries()
returns table (therapist_id uuid, rating_average numeric, rating_count integer)
language sql
stable
security definer
set search_path = ''
as $$
  select r.therapist_id, round(avg(rt.rating)::numeric, 1), count(*)::integer
  from public.therapy_ratings rt
  join public.therapy_requests r on r.id = rt.request_id
  where rt.author_role = 'client' and r.therapist_id is not null
  group by r.therapist_id
  having count(*) >= 3 or public.is_admin();
$$;

create or replace function public.admin_list_therapy_requests()
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

create or replace function public.admin_list_therapists()
returns table (
  id uuid,
  full_name text,
  title text,
  credentials text,
  bio text,
  specialties text[],
  languages text[],
  years_experience smallint,
  photo_url text,
  active boolean,
  email text,
  has_account boolean,
  upcoming_sessions integer,
  completed_sessions integer,
  rating_average numeric,
  rating_count integer
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
  select t.id, t.full_name, t.title, t.credentials, t.bio, t.specialties,
         t.languages, t.years_experience, t.photo_url, t.active,
         ta.email,
         exists (
           select 1 from auth.users u
           where lower(u.email) = ta.email and u.email_confirmed_at is not null
         ),
         (select count(*)::integer from public.therapy_requests r
          where r.therapist_id = t.id and r.status = 'confirmed'),
         (select count(*)::integer from public.therapy_requests r
          where r.therapist_id = t.id and r.status = 'completed'),
         (select round(avg(rt.rating)::numeric, 1)
          from public.therapy_ratings rt
          join public.therapy_requests r on r.id = rt.request_id
          where r.therapist_id = t.id and rt.author_role = 'client'),
         (select count(*)::integer
          from public.therapy_ratings rt
          join public.therapy_requests r on r.id = rt.request_id
          where r.therapist_id = t.id and rt.author_role = 'client')
  from public.therapists t
  left join public.therapist_accounts ta on ta.therapist_id = t.id
  order by t.active desc, t.full_name;
end;
$$;

create or replace function public.admin_save_therapist(
  p_id uuid,
  p_full_name text,
  p_email text,
  p_title text,
  p_credentials text,
  p_bio text,
  p_specialties text[],
  p_languages text[],
  p_years_experience integer,
  p_photo_url text,
  p_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  therapist uuid := p_id;
  clean_email text := nullif(lower(trim(p_email)), '');
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if clean_email is null or clean_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Enter the email address the therapist will sign in with.'
      using errcode = '22023';
  end if;
  if length(trim(coalesce(p_full_name, ''))) < 2 then
    raise exception 'Enter the therapist’s full name.' using errcode = '22023';
  end if;

  if therapist is null then
    insert into public.therapists (
      full_name, title, credentials, bio, specialties, languages,
      years_experience, photo_url, active
    )
    values (
      trim(p_full_name), nullif(trim(p_title), ''), nullif(trim(p_credentials), ''),
      nullif(trim(p_bio), ''), coalesce(p_specialties, '{}'),
      coalesce(p_languages, '{}'), p_years_experience,
      nullif(trim(p_photo_url), ''), coalesce(p_active, true)
    )
    returning id into therapist;
  else
    update public.therapists
    set full_name = trim(p_full_name),
        title = nullif(trim(p_title), ''),
        credentials = nullif(trim(p_credentials), ''),
        bio = nullif(trim(p_bio), ''),
        specialties = coalesce(p_specialties, '{}'),
        languages = coalesce(p_languages, '{}'),
        years_experience = p_years_experience,
        photo_url = nullif(trim(p_photo_url), ''),
        active = coalesce(p_active, true),
        updated_at = now()
    where id = therapist;
    if not found then
      raise exception 'That therapist no longer exists.' using errcode = 'P0002';
    end if;
  end if;

  insert into public.therapist_accounts (therapist_id, email)
  values (therapist, clean_email)
  on conflict (therapist_id) do update set email = excluded.email;

  return therapist;
exception
  when unique_violation then
    raise exception 'Another therapist already signs in with that email.'
      using errcode = '23505';
end;
$$;

create or replace function public.admin_match_therapy_request(
  p_request_id uuid,
  p_therapist_id uuid,
  p_scheduled_at timestamptz,
  p_duration_minutes integer default 50
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
  select * into req from public.therapy_requests
    where id = p_request_id for update;
  if not found then
    raise exception 'That request no longer exists.' using errcode = 'P0002';
  end if;
  if req.status not in ('pending', 'confirmed') then
    raise exception 'Only an open request can be matched.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.therapists where id = p_therapist_id and active
  ) then
    raise exception 'Choose an active therapist.' using errcode = '22023';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 15 and 180 then
    raise exception 'Sessions run between 15 and 180 minutes.' using errcode = '22023';
  end if;
  if p_scheduled_at is null or p_scheduled_at < now() - interval '5 minutes' then
    raise exception 'Pick a time that hasn’t passed.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.therapy_requests r
    where r.therapist_id = p_therapist_id
      and r.status = 'confirmed'
      and r.id <> p_request_id
      and tstzrange(r.scheduled_at,
                    r.scheduled_at + make_interval(mins => r.duration_minutes::integer))
          && tstzrange(p_scheduled_at,
                       p_scheduled_at + make_interval(mins => p_duration_minutes))
  ) then
    raise exception 'That therapist already has a session at that time.'
      using errcode = '23P01';
  end if;

  update public.therapy_requests
  set therapist_id = p_therapist_id,
      scheduled_at = p_scheduled_at,
      duration_minutes = p_duration_minutes,
      status = 'confirmed',
      confirmed_at = coalesce(confirmed_at, now())
  where id = p_request_id;
end;
$$;

-- Payments the app didn't take: cash, a bank transfer, a goodwill waiver,
-- or correcting a mistake. In-app purchases are recorded by the
-- confirm-session-payment Edge Function instead.
create or replace function public.admin_set_therapy_payment(
  p_request_id uuid,
  p_payment_status text
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
  if p_payment_status not in ('paid', 'waived', 'unpaid') then
    raise exception 'Unknown payment status.' using errcode = '22023';
  end if;
  update public.therapy_requests
  set payment_status = p_payment_status,
      paid_at = case when p_payment_status = 'paid'
                     then coalesce(paid_at, now()) end,
      payment_ref = case when p_payment_status = 'paid'
                         then coalesce(payment_ref, 'manual:' || gen_random_uuid()) end
  where id = p_request_id and price_cents > 0;
  if not found then
    raise exception 'This session has nothing to pay.' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.admin_cancel_therapy_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  update public.therapy_requests
  set status = 'cancelled', cancelled_at = now()
  where id = p_request_id and status in ('pending', 'confirmed');
  if not found then
    raise exception 'Only an open request can be cancelled.' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.therapist_list_sessions()
returns table (
  id uuid,
  status text,
  topic text,
  availability text[],
  note text,
  scheduled_at timestamptz,
  duration_minutes smallint,
  payment_status text,
  is_free_session boolean,
  client_first_name text,
  client_summary text,
  completed_at timestamptz,
  my_rating smallint,
  my_comment text,
  my_flags text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  return query
  select r.id, r.status, r.topic, r.availability, r.note, r.scheduled_at,
         r.duration_minutes, r.payment_status, r.is_free_session,
         public.therapy_client_first_name(r.user_id),
         r.client_summary, r.completed_at,
         tr.rating, tr.comment, tr.flags
  from public.therapy_requests r
  left join public.therapy_ratings tr
    on tr.request_id = r.id and tr.author_role = 'therapist'
  where r.therapist_id = me
    and r.status in ('confirmed', 'completed', 'cancelled')
  order by r.scheduled_at desc nulls last
  limit 300;
end;
$$;

-- The therapist (or an admin) closes a session once it has started, with an
-- optional note the client sees. Calling it again edits the note.
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
  if req.status <> 'confirmed' then
    raise exception 'Only a confirmed session can be completed.' using errcode = '22023';
  end if;
  if req.scheduled_at > now() then
    raise exception 'This session hasn’t started yet.' using errcode = '22023';
  end if;
  update public.therapy_requests
  set status = 'completed',
      completed_at = now(),
      client_summary = nullif(trim(p_summary), '')
  where id = p_request_id;
end;
$$;

create or replace function public.rate_therapy_session(
  p_request_id uuid,
  p_rating integer,
  p_comment text default null,
  p_flags text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  req public.therapy_requests%rowtype;
  author text;
  clean_flags text[] := '{}';
  therapist_name text;
begin
  select * into req from public.therapy_requests where id = p_request_id;
  if not found then
    raise exception 'That session no longer exists.' using errcode = 'P0002';
  end if;
  if req.user_id = auth.uid() then
    author := 'client';
  elsif req.therapist_id is not null
        and req.therapist_id = public.current_therapist_id() then
    author := 'therapist';
  else
    raise exception 'That session isn’t one of yours.' using errcode = 'P0002';
  end if;
  if req.status <> 'completed' then
    raise exception 'You can rate a session once it’s finished.' using errcode = '22023';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'Ratings go from 1 to 5.' using errcode = '22023';
  end if;
  if author = 'therapist' then
    clean_flags := array(
      select distinct f from unnest(coalesce(p_flags, '{}')) f
      where f in ('no_show', 'late', 'safety_concern', 'follow_up')
    );
  end if;

  insert into public.therapy_ratings (
    request_id, author_role, author_id, rating, comment, flags
  )
  values (
    p_request_id, author, auth.uid(), p_rating,
    nullif(trim(p_comment), ''), clean_flags
  )
  on conflict (request_id, author_role) do update
  set rating = excluded.rating,
      comment = excluded.comment,
      flags = excluded.flags,
      author_id = excluded.author_id,
      updated_at = now();

  -- A therapist worried about someone's safety shouldn't have to hope the
  -- care team happens to open the dashboard.
  if author = 'therapist' and 'safety_concern' = any(clean_flags) then
    select t.full_name into therapist_name
      from public.therapists t where t.id = req.therapist_id;
    perform public.send_app_email(
      care_team,
      null,
      'Safety concern flagged after a session',
      public.email_layout(
        'A therapist flagged a safety concern.',
        'Safety concern flagged',
        public.email_escape(coalesce(therapist_name, 'A therapist'))
          || ' flagged a safety concern after their session with '
          || public.email_escape(coalesce(public.therapy_client_first_name(req.user_id), 'a client'))
          || '. Please follow up today.',
        public.email_box('#F3F6FC', 'Session',
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
          || public.email_row('When', public.email_escape(public.email_session_time(req.scheduled_at)))
          || public.email_row('Focus', public.email_escape(req.topic))
          || public.email_row('Their note', replace(public.email_escape(coalesce(nullif(trim(p_comment), ''), '—')), E'\n', '<br>'))
          || public.email_row('Request ID',
               '<span style="font-family:Menlo,Consolas,monospace;font-size:12px;color:#6E6E73;">'
               || req.id || '</span>')
          || '</table>'),
        'Open Settings → Care team in the app for the client’s contact details.'
      ),
      coalesce(therapist_name, 'A therapist') || ' flagged a safety concern after '
        || 'their session with ' || coalesce(public.therapy_client_first_name(req.user_id), 'a client')
        || ' (' || public.email_session_time(req.scheduled_at) || ').'
        || E'\n\n' || 'Their note: ' || coalesce(nullif(trim(p_comment), ''), '—')
        || E'\n\n' || 'Request ID: ' || req.id
        || E'\n\n' || 'Open Settings → Care team in the app for the client’s contact details.',
      'therapy-session/' || req.id || '/safety/' || extract(epoch from now())::bigint
    );
  end if;
end;
$$;

-- ── Grants ───────────────────────────────────────────────────────────
-- Supabase grants execute on new public functions to anon and
-- authenticated by default. Internal helpers get locked down entirely; the
-- app-facing ones are for signed-in users only, and check roles inside.

revoke execute on function public.current_user_email() from public, anon;
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.current_therapist_id() from public, anon;
revoke execute on function public.send_app_email(text, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.email_session_time(timestamptz) from public, anon, authenticated;
revoke execute on function public.therapy_client_first_name(uuid) from public, anon, authenticated;
revoke execute on function public.notify_therapy_session_change() from public, anon, authenticated;
revoke execute on function public.notify_therapist_invited() from public, anon, authenticated;

revoke execute on function public.my_care_roles() from public, anon;
revoke execute on function public.therapist_rating_summaries() from public, anon;
revoke execute on function public.admin_list_therapy_requests() from public, anon;
revoke execute on function public.admin_list_therapists() from public, anon;
revoke execute on function public.admin_save_therapist(uuid, text, text, text, text, text, text[], text[], integer, text, boolean) from public, anon;
revoke execute on function public.admin_match_therapy_request(uuid, uuid, timestamptz, integer) from public, anon;
revoke execute on function public.admin_set_therapy_payment(uuid, text) from public, anon;
revoke execute on function public.admin_cancel_therapy_request(uuid) from public, anon;
revoke execute on function public.therapist_list_sessions() from public, anon;
revoke execute on function public.complete_therapy_session(uuid, text) from public, anon;
revoke execute on function public.rate_therapy_session(uuid, integer, text, text[]) from public, anon;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.current_therapist_id() to authenticated;
grant execute on function public.my_care_roles() to authenticated;
grant execute on function public.therapist_rating_summaries() to authenticated;
grant execute on function public.admin_list_therapy_requests() to authenticated;
grant execute on function public.admin_list_therapists() to authenticated;
grant execute on function public.admin_save_therapist(uuid, text, text, text, text, text, text[], text[], integer, text, boolean) to authenticated;
grant execute on function public.admin_match_therapy_request(uuid, uuid, timestamptz, integer) to authenticated;
grant execute on function public.admin_set_therapy_payment(uuid, text) to authenticated;
grant execute on function public.admin_cancel_therapy_request(uuid) to authenticated;
grant execute on function public.therapist_list_sessions() to authenticated;
grant execute on function public.complete_therapy_session(uuid, text) to authenticated;
grant execute on function public.rate_therapy_session(uuid, integer, text, text[]) to authenticated;
