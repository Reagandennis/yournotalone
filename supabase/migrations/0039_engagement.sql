-- Engagement: visits, the holdout group, win-back emails and the numbers
-- that show whether any of it works. The app side is lib/engagement/.
--
--   1. app_presence_days    one row per person per day the app was opened,
--                           written by touch_app_presence() from the app.
--   2. engagement_holdout() the one-in-ten accounts that keep the app as it
--                           was (no nudges, plain reminders, no win-back
--                           emails), to measure the engine against. Must
--                           match isEngagementHoldout() in
--                           lib/engagement/engagement.dart.
--   3. email_preferences    the "Emails when you've been away" switch, and a
--                           token per account for the unsubscribe link.
--   4. send_engagement_emails()
--                           at most two emails per time away — after 10 and
--                           after 30 days — and never two within a week.
--                           Sent in batches through Resend's batch endpoint
--                           (one request per run, so the rate limit holds),
--                           every one with one-click unsubscribe headers.
--   5. admin_engagement_retention()
--                           day-1, day-7 and day-30 retention by signup week,
--                           engine against holdout.
--
-- What's NOT here: anything from Apple Health / Health Connect. That stays
-- on the phone (lib/health/health_service.dart).
--
-- Run in Supabase dashboard → SQL Editor, after 0038 (it was written as
-- 0036 on the retention-health branch and renumbered when merged). Then deploy the
-- unsubscribe function:
--   supabase functions deploy email-preferences --no-verify-jwt
--
-- Emails go out only once the Resend key is in Vault (see 0008), from the
-- resend_from sender. Until a sending domain is verified in Resend they
-- are refused for everyone but the Resend account owner, harmlessly.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ── 1. Visits ──────────────────────────────────────────────────────────

create table if not exists public.app_presence_days (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);
alter table public.app_presence_days enable row level security;
-- No policies: written by touch_app_presence(), read by the functions below.

-- The day comes from the phone, in its own time zone, so "today" is the
-- person's today. A date more than a day from the server's is the phone's
-- clock being wrong; the server's date is used instead.
create or replace function public.touch_app_presence(p_day date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  server_day date := (now() at time zone 'utc')::date;
begin
  if auth.uid() is null then
    return;
  end if;
  if p_day is null or p_day not between server_day - 1 and server_day + 1 then
    p_day := server_day;
  end if;
  insert into public.app_presence_days (user_id, day)
  values (auth.uid(), p_day)
  on conflict do nothing;
end;
$$;

revoke all on function public.touch_app_presence(date) from public, anon;
grant execute on function public.touch_app_presence(date) to authenticated;

-- ── 2. The holdout group ───────────────────────────────────────────────

-- The first 8 hex digits of md5(account id), as an unsigned number, mod
-- 100, under 10. Padded to 64 bits so the number is never negative.
create or replace function public.engagement_holdout(p_user_id uuid)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (('x' || lpad(substr(md5(p_user_id::text), 1, 8), 16, '0'))::bit(64)::bigint % 100) < 10;
$$;

revoke all on function public.engagement_holdout(uuid) from public, anon, authenticated;

-- ── 3. Email preferences ───────────────────────────────────────────────

create table if not exists public.email_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  engagement boolean not null default true,
  -- In the unsubscribe link: stops the emails without signing in, and
  -- can do nothing else.
  unsubscribe_token uuid not null unique default gen_random_uuid(),
  updated_at timestamptz not null default now()
);
alter table public.email_preferences enable row level security;
-- No policies: read and written through the functions below.

create or replace function public.get_engagement_emails()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.engagement from public.email_preferences p where p.user_id = auth.uid()),
    true
  );
$$;

create or replace function public.set_engagement_emails(p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  insert into public.email_preferences (user_id, engagement, updated_at)
  values (auth.uid(), coalesce(p_on, true), now())
  on conflict (user_id) do update
    set engagement = excluded.engagement, updated_at = now();
end;
$$;

revoke all on function public.get_engagement_emails() from public, anon;
revoke all on function public.set_engagement_emails(boolean) from public, anon;
grant execute on function public.get_engagement_emails() to authenticated;
grant execute on function public.set_engagement_emails(boolean) to authenticated;

-- For the email-preferences Edge Function (service role): the unsubscribe
-- link. True when the token was real.
create or replace function public.email_unsubscribe(p_token uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.email_preferences
     set engagement = false, updated_at = now()
   where unsubscribe_token = p_token;
  return found;
end;
$$;

revoke all on function public.email_unsubscribe(uuid) from public, anon, authenticated;
grant execute on function public.email_unsubscribe(uuid) to service_role;

-- ── 4. Win-back emails ─────────────────────────────────────────────────

create table if not exists public.engagement_emails (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('away_10', 'away_30')),
  -- The last day they were active: one email of each kind per time away.
  away_since date not null,
  sent_at timestamptz not null default now(),
  primary key (user_id, kind, away_since)
);
alter table public.engagement_emails enable row level security;
-- No policies: written by send_engagement_emails() only.

-- Every day someone used the app: opened it, checked in, practised or
-- wrote. Journal and practice times are UTC; their dates are close enough
-- for counting days away.
create or replace function public.engagement_active_days(p_user_id uuid)
returns table (day date)
language sql
stable
security definer
set search_path = ''
as $$
  select d.day from public.app_presence_days d where d.user_id = p_user_id
  union
  select m.entry_date from public.mood_entries m where m.user_id = p_user_id
  union
  select (j.created_at at time zone 'utc')::date from public.journal_entries j where j.user_id = p_user_id
  union
  select (s.completed_at at time zone 'utc')::date from public.practice_sessions s where s.user_id = p_user_id;
$$;

revoke all on function public.engagement_active_days(uuid) from public, anon, authenticated;

create or replace function public.send_engagement_emails(p_limit int default 100)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  unsubscribe_base constant text :=
    'https://zpcfavemnvfhqaxqhmri.supabase.co/functions/v1/email-preferences?t=';
  strong constant text := '<strong style="font-weight:600;color:#191919;">';
  api_key text;
  sender text;
  r record;
  token uuid;
  link text;
  first_name text;
  total_days int;
  subject text;
  headline text;
  intro text;
  box text;
  plain text;
  batch jsonb := '[]'::jsonb;
  keys text := '';
  sent int := 0;
begin
  select decrypted_secret into api_key
    from vault.decrypted_secrets where name = 'resend_api_key';
  if api_key is null then
    return 0;
  end if;
  select decrypted_secret into sender
    from vault.decrypted_secrets where name = 'resend_from';
  sender := coalesce(nullif(trim(sender), ''), 'Den eisai monos <onboarding@resend.dev>');

  for r in
    with people as (
      select u.id, u.email::text as email,
             (select max(a.day) from public.engagement_active_days(u.id) a) as last_active
        from auth.users u
       where u.email is not null
         and u.email_confirmed_at is not null
         and u.deleted_at is null
         and coalesce(u.is_anonymous, false) = false
         -- Apple's Hide My Email relays only accept mail from a domain
         -- registered with Apple. Until the Resend domain is (see the Sign in
         -- with Apple notes), these would bounce and hurt the sender's
         -- reputation. Remove this line once it is.
         and u.email not ilike '%@privaterelay.appleid.com'
         and u.created_at < now() - interval '3 days'
         and not public.engagement_holdout(u.id)
         and not exists (
           select 1 from public.email_preferences p
            where p.user_id = u.id and not p.engagement)
         -- Therapists and the care team use the app for work.
         and not exists (
           select 1 from public.therapist_accounts t where t.email = lower(u.email))
         and not exists (
           select 1 from public.admins a where a.email = lower(u.email))
         -- Never two of these emails in a week.
         and not exists (
           select 1 from public.engagement_emails e
            where e.user_id = u.id and e.sent_at > now() - interval '7 days')
    )
    select p.id, p.email, p.last_active,
           case
             when (now() at time zone 'utc')::date - p.last_active between 30 and 33 then 'away_30'
             else 'away_10'
           end as kind
      from people p
     where p.last_active is not null
       and (
         (now() at time zone 'utc')::date - p.last_active between 10 and 13
         or (now() at time zone 'utc')::date - p.last_active between 30 and 33
       )
     order by p.last_active
     limit greatest(1, least(coalesce(p_limit, 100), 100))
  loop
    insert into public.engagement_emails (user_id, kind, away_since)
    values (r.id, r.kind, r.last_active)
    on conflict do nothing;
    if not found then
      continue;
    end if;

    insert into public.email_preferences (user_id) values (r.id)
    on conflict (user_id) do nothing;
    select p.unsubscribe_token into token
      from public.email_preferences p where p.user_id = r.id;
    link := unsubscribe_base || token::text;
    first_name := coalesce(public.therapy_client_first_name(r.id), 'there');
    select count(*) into total_days from public.engagement_active_days(r.id);

    if r.kind = 'away_10' then
      subject := 'Your space is still here, ' || first_name;
      headline := 'We kept your place';
      intro := 'Hi ' || public.email_escape(first_name) || ', it’s been a '
        || 'little while. There’s nothing to catch up on: everything you '
        || 'saved is right where you left it.';
      box := public.email_box('#F3F6FC', 'Three minutes, if you have them',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Open the app for a breathing exercise or a ten-second check-in. '
        || 'You’ve shown up for yourself on ' || strong || total_days
        || case when total_days = 1 then ' day' else ' days' end
        || '</strong> so far, and one small step still counts.<br><br>'
        || 'If things are hard right now, the app’s ' || strong
        || 'Support</strong> page has people you can talk to today, wherever '
        || 'you are.</div>');
      plain := 'Hi ' || first_name || ','
        || E'\n\n' || 'It’s been a little while. There’s nothing to catch up '
        || 'on: everything you saved is right where you left it.'
        || E'\n\n' || 'Open the app for a breathing exercise or a ten-second '
        || 'check-in. You’ve shown up for yourself on ' || total_days
        || case when total_days = 1 then ' day' else ' days' end
        || ' so far, and one small step still counts.'
        || E'\n\n' || 'If things are hard right now, the app’s Support page '
        || 'has people you can talk to today, wherever you are.';
    else
      subject := 'One last note from us';
      headline := 'Whenever you’re ready';
      intro := 'Hi ' || public.email_escape(first_name) || ', this is the '
        || 'last email we’ll send about being away. Your journal, check-ins '
        || 'and progress stay safe in your account for whenever you want them.';
      box := public.email_box('#F6F6F6', 'If now isn’t the time',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'That’s okay. If something about the app didn’t work for you, '
        || strong || 'reply to this email</strong>: it reaches a person, and '
        || 'it changes what we build.<br><br>'
        || 'If things are hard, the app’s ' || strong || 'Support</strong> '
        || 'page has people you can talk to today.</div>');
      plain := 'Hi ' || first_name || ','
        || E'\n\n' || 'This is the last email we’ll send about being away. '
        || 'Your journal, check-ins and progress stay safe in your account '
        || 'for whenever you want them.'
        || E'\n\n' || 'If something about the app didn’t work for you, reply '
        || 'to this email: it reaches a person.'
        || E'\n\n' || 'If things are hard, the app’s Support page has people '
        || 'you can talk to today.';
    end if;

    plain := plain || E'\n\n' || '— Δεν είσαι μόνος'
      || E'\n\n' || 'Stop these emails: ' || link
      || E'\n' || 'Or in the app: Settings → Reminders.';

    batch := batch || jsonb_build_array(jsonb_build_object(
      'from', sender,
      'to', jsonb_build_array(r.email),
      'reply_to', care_team,
      'subject', subject,
      'html', public.email_layout(
        public.email_escape(subject),
        headline,
        intro,
        box,
        'You’re getting this because you have an account with Δεν είσαι '
          || 'μόνος, and haven’t opened the app in a while. '
          || '<a href="' || link || '">Stop these emails</a> (one tap, no '
          || 'sign-in), or turn them off in the app under Settings → '
          || 'Reminders.'
      ),
      'text', plain,
      -- RFC 8058 one-click unsubscribe, which Gmail and Yahoo require of
      -- bulk senders and show as an "Unsubscribe" link by the sender.
      'headers', jsonb_build_object(
        'List-Unsubscribe', '<' || link || '>',
        'List-Unsubscribe-Post', 'List-Unsubscribe=One-Click'
      ),
      'tags', jsonb_build_array(jsonb_build_object('name', 'kind', 'value', r.kind))
    ));
    keys := keys || r.id::text || r.kind || r.last_active::text;
    sent := sent + 1;
  end loop;

  if sent = 0 then
    return 0;
  end if;
  begin
    perform net.http_post(
      url := 'https://api.resend.com/emails/batch',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || api_key,
        'Content-Type', 'application/json',
        'Idempotency-Key', 'engagement/' || md5(keys)
      ),
      body := batch,
      timeout_milliseconds := 20000
    );
  exception when others then
    raise warning 'engagement emails failed: %', sqlerrm;
  end;
  return sent;
end;
$$;

revoke all on function public.send_engagement_emails(int) from public, anon, authenticated;
grant execute on function public.send_engagement_emails(int) to service_role;

-- Every half hour from 07:00 to 10:30 UTC — mid-morning in Nairobi, early
-- morning in Athens — up to 100 a run.
select cron.unschedule('engagement-emails')
 where exists (select 1 from cron.job where jobname = 'engagement-emails');
select cron.schedule(
  'engagement-emails',
  '*/30 7-10 * * *',
  $$select public.send_engagement_emails(100)$$
);

-- Visits older than 400 days aren't needed for any of the numbers.
select cron.unschedule('app-presence-cleanup')
 where exists (select 1 from cron.job where jobname = 'app-presence-cleanup');
select cron.schedule(
  'app-presence-cleanup',
  '41 3 * * *',
  $$delete from public.app_presence_days where day < current_date - 400$$
);

-- ── 5. Is it working? ──────────────────────────────────────────────────

-- For each signup week: how many people signed up, and the share who came
-- back on day 1, in days 7–13 and in days 30–36 — the engine's group and
-- the holdout side by side. A cell is null until that whole window has
-- passed for the week. Run it from the SQL Editor:
--   select * from public.admin_engagement_retention();
create or replace function public.admin_engagement_retention(p_weeks int default 12)
returns table (
  signup_week date,
  cohort text,
  people int,
  day_1 numeric,
  days_7_13 numeric,
  days_30_36 numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_admin() or current_user in ('postgres', 'supabase_admin')) then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return query
  with signups as (
    select u.id,
           (u.created_at at time zone 'utc')::date as joined,
           case when public.engagement_holdout(u.id) then 'holdout' else 'engine' end as grp
      from auth.users u
     where u.created_at >= date_trunc('week', now()) - make_interval(weeks => greatest(p_weeks, 1))
       and not exists (
         select 1 from public.therapist_accounts t where t.email = lower(u.email))
  ),
  marks as (
    select s.id, s.joined, s.grp,
           bool_or(a.day = s.joined + 1) as d1,
           bool_or(a.day between s.joined + 7 and s.joined + 13) as d7,
           bool_or(a.day between s.joined + 30 and s.joined + 36) as d30
      from signups s
      left join lateral public.engagement_active_days(s.id) a on true
     group by s.id, s.joined, s.grp
  )
  select date_trunc('week', m.joined)::date,
         m.grp,
         count(*)::int,
         case when max(m.joined) + 1 < current_date
           then round(100.0 * count(*) filter (where m.d1) / count(*), 1) end,
         case when max(m.joined) + 13 < current_date
           then round(100.0 * count(*) filter (where m.d7) / count(*), 1) end,
         case when max(m.joined) + 36 < current_date
           then round(100.0 * count(*) filter (where m.d30) / count(*), 1) end
    from marks m
   group by 1, 2
   order by 1 desc, 2;
end;
$$;

revoke all on function public.admin_engagement_retention(int) from public, anon;
grant execute on function public.admin_engagement_retention(int) to authenticated;
