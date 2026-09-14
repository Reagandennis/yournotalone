-- Phone notifications and reminders for therapy sessions — without a push
-- service.
--
-- The app deliberately doesn't use Firebase, so nothing here can wake a
-- phone. Instead:
--   • Session events — booked, changed, cancelled, and the reminder — are
--     queued in public.app_notifications for the client and the therapist.
--     The app collects them when it opens, and in the background about every
--     15 minutes on Android, and shows them as phone notifications in the
--     phone's own time zone.
--   • The app also schedules each upcoming session's 10-minute reminder on
--     the phone itself, so it fires even if the phone is offline by then.
--   • pg_cron emails both people 10 minutes before every session, and queues
--     the reminder for any phone that hadn't heard about the session in time.
--
-- Background checks can't use the signed-in session: refreshing its tokens
-- from a background isolate races the app and can sign people out. Each
-- install registers a random key instead — only its SHA-256 is stored — and
-- that key reads the owner's session notifications and nothing else.
--
-- Run after 0009. Safe to re-run.

create extension if not exists pg_cron;

create table if not exists public.notification_devices (
  key_hash text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'other'
    check (platform in ('android', 'ios', 'macos', 'other')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists notification_devices_user_idx
  on public.notification_devices (user_id);

alter table public.notification_devices enable row level security;
-- No policies: only the functions below touch it.

create table if not exists public.app_notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in (
    'session_booked', 'session_changed', 'session_cancelled', 'session_reminder'
  )),
  -- Facts, not sentences: the app writes the words, in the phone's time zone.
  data jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists app_notifications_user_idx
  on public.app_notifications (user_id, id);

alter table public.app_notifications enable row level security;
-- No policies: read through device_session_sync() only.

alter table public.therapy_requests
  add column if not exists reminder_sent_at timestamptz;

-- 0009's guard, plus one rule: a session that moves is reminded about again
-- at its new time.
create or replace function public.therapy_requests_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.scheduled_at is distinct from old.scheduled_at then
    new.reminder_sent_at := null;
  end if;
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

-- ── Queueing ─────────────────────────────────────────────────────────

-- The account a therapist signs in with, once they've confirmed it.
create or replace function public.therapist_user_id(p_therapist_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public.therapist_accounts ta
  join auth.users u
    on lower(u.email) = ta.email and u.email_confirmed_at is not null
  where ta.therapist_id = p_therapist_id
  limit 1;
$$;

-- What one side needs to describe a session. The client learns the
-- therapist's name; the therapist learns only the client's first name.
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
    'is_free_session', r.is_free_session,
    'counterpart', case
      when p_role = 'client' then
        (select t.full_name from public.therapists t where t.id = r.therapist_id)
      else public.therapy_client_first_name(r.user_id)
    end
  );
$$;

create or replace function public.queue_session_notifications(
  r public.therapy_requests,
  p_kind text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  therapist_user uuid := public.therapist_user_id(r.therapist_id);
begin
  insert into public.app_notifications (user_id, kind, data)
  values (r.user_id, p_kind, public.session_notification_data(r, 'client'));
  if therapist_user is not null and therapist_user <> r.user_id then
    insert into public.app_notifications (user_id, kind, data)
    values (therapist_user, p_kind, public.session_notification_data(r, 'therapist'));
  end if;
end;
$$;

-- The same moments 0009 emails about.
create or replace function public.notify_session_devices()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed' and (
       old.status is distinct from 'confirmed'
       or old.scheduled_at is distinct from new.scheduled_at
       or old.therapist_id is distinct from new.therapist_id) then
    perform public.queue_session_notifications(
      new,
      case when old.status = 'confirmed' then 'session_changed' else 'session_booked' end
    );
  elsif old.status = 'confirmed' and new.status = 'cancelled' then
    perform public.queue_session_notifications(new, 'session_cancelled');
  end if;
  return new;
exception when others then
  raise warning 'session % notification failed: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists therapy_session_devices on public.therapy_requests;
create trigger therapy_session_devices
  after update on public.therapy_requests
  for each row execute function public.notify_session_devices();

-- ── Reminders ────────────────────────────────────────────────────────

-- Every minute: each confirmed session starting within 10 minutes gets one
-- reminder — an email to the client and the therapist, and a notification
-- queued for their phones. Returns how many sessions were reminded.
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
            || 'Open the app, go to ' || strong || 'Settings → My therapy '
            || 'sessions</strong> and tap ' || strong || 'Join session</strong>.</div>'),
          'Session time: ' || public.email_escape(when_text) || '.'
        ),
        'Your session with ' || coalesce(client_first, 'your client') || ' '
          || starts || ' (' || when_text || ').'
          || E'\n\n'
          || case when unpaid
             then 'The client hasn’t paid yet — the call opens once they do.' || E'\n\n'
             else '' end
          || 'Open the app, go to Settings → My therapy sessions and tap Join session.',
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

select cron.schedule(
  'therapy-session-reminders',
  '* * * * *',
  $$select public.send_session_reminders()$$
);

select cron.schedule(
  'app-notifications-cleanup',
  '17 3 * * *',
  $$delete from public.app_notifications where created_at < now() - interval '30 days';
    delete from public.notification_devices where last_seen_at < now() - interval '90 days'$$
);

-- ── For the app ──────────────────────────────────────────────────────

-- Called by the signed-in app for this install's random key. Returns the
-- newest notification id, so a fresh install starts from now rather than
-- replaying old news.
create or replace function public.register_notification_device(
  p_key text,
  p_platform text default 'other'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if length(coalesce(p_key, '')) < 32 then
    raise exception 'That device key is too short.' using errcode = '22023';
  end if;
  insert into public.notification_devices (key_hash, user_id, platform)
  values (
    encode(sha256(convert_to(p_key, 'UTF8')), 'hex'),
    me,
    case when p_platform in ('android', 'ios', 'macos') then p_platform else 'other' end
  )
  on conflict (key_hash) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      last_seen_at = now();
  return coalesce(
    (select max(n.id) from public.app_notifications n where n.user_id = me),
    0
  );
end;
$$;

create or replace function public.unregister_notification_device(p_key text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.notification_devices
  where key_hash = encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex')
    and user_id = auth.uid();
$$;

-- What a device's background check needs, by key alone: notifications after
-- the last one it showed, the sessions coming up (to schedule reminders),
-- and whether there's anything worth checking for at all.
create or replace function public.device_session_sync(
  p_key text,
  p_after bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  device public.notification_devices%rowtype;
  therapist uuid;
begin
  update public.notification_devices
  set last_seen_at = now()
  where key_hash = encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex')
  returning * into device;
  if not found then
    return jsonb_build_object('registered', false);
  end if;

  select ta.therapist_id into therapist
    from public.therapist_accounts ta
    join auth.users u
      on lower(u.email) = ta.email and u.email_confirmed_at is not null
    where u.id = device.user_id
    limit 1;

  return jsonb_build_object(
    'registered', true,
    'notifications', coalesce((
      select jsonb_agg(
        jsonb_build_object('id', n.id, 'kind', n.kind, 'data', n.data)
        order by n.id)
      from (
        select * from public.app_notifications
        where user_id = device.user_id
          and id > coalesce(p_after, 0)
          and created_at > now() - interval '3 days'
        order by id
        limit 50
      ) n
    ), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(
        public.session_notification_data(
          r, case when r.user_id = device.user_id then 'client' else 'therapist' end)
        order by r.scheduled_at)
      from public.therapy_requests r
      where r.status = 'confirmed'
        and r.scheduled_at > now() - interval '15 minutes'
        and r.scheduled_at < now() + interval '30 days'
        and (r.user_id = device.user_id
             or (therapist is not null and r.therapist_id = therapist))
    ), '[]'::jsonb),
    'active', therapist is not null or exists (
      select 1 from public.therapy_requests r
      where r.user_id = device.user_id and r.status in ('pending', 'confirmed')
    )
  );
end;
$$;

-- ── Grants ───────────────────────────────────────────────────────────

revoke execute on function public.therapist_user_id(uuid) from public, anon, authenticated;
revoke execute on function public.session_notification_data(public.therapy_requests, text) from public, anon, authenticated;
revoke execute on function public.queue_session_notifications(public.therapy_requests, text) from public, anon, authenticated;
revoke execute on function public.notify_session_devices() from public, anon, authenticated;
revoke execute on function public.send_session_reminders() from public, anon, authenticated;

revoke execute on function public.register_notification_device(text, text) from public, anon;
revoke execute on function public.unregister_notification_device(text) from public, anon;
grant execute on function public.register_notification_device(text, text) to authenticated;
grant execute on function public.unregister_notification_device(text) to authenticated;

-- The key is the credential here, so anon may call it.
grant execute on function public.device_session_sync(text, bigint) to anon, authenticated;
