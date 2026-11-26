-- 0037: platform fixes from the 26 November 2026 review.
--
--  1. Therapists no longer read session rows directly: their sessions
--     come through therapist_list_sessions(), which leaves out the
--     client's account id and the payment references.
--  2. The hourly brake on new requests counts requests that were sent,
--     not drafts, so unpaid drafts can't shut booking for everyone.
--  3. A therapist taken off a session hears it's cancelled (email and
--     phone); the therapist given it hears it's new, not "updated". No
--     phone notification is queued for a client whose account is gone.
--  4. Moving a session back to a time it had before sends its emails
--     again (each change has its own idempotency key).
--  5. Rating summaries give non-admins a rounded-down count (3, 5, 10,
--     25, 50, …) and, under ten ratings, an average to the half star, so
--     no single rating can be worked out. A client who didn't join can't
--     rate the session, and older ratings like that aren't counted.
--  6. A pledge can only be made for one's own habit.
--  7. Approving or declining an application can name the version the
--     admin checked (p_reviewed_updated_at); a newer one is refused. The
--     care team is emailed at most once per applicant in ten minutes.
--  8. Changing a therapist's main country doesn't carry the old country's
--     licence over to the new one.
--  9. report_site_error is throttled per caller, never evicts faults
--     nobody has looked at, and a flood can't use up the email allowance.
-- 10. Practice sessions can't be dated in the future (popularity counts
--     only up to now); slugs and titles have length limits; saved items
--     and session feelings have a per-person cap.
-- 11. Therapist photos must come from this project's own storage.
-- 13. Old overloads left by re-running earlier files are dropped.
--
-- Apply migrations in order, once each. Don't re-run an older file after a
-- newer one: it puts back the older version of every function it defines
-- (re-running 0033 after 0034 resets the therapist agreement version;
-- re-running 0034 after 0035 adds a second therapy_detect_country beside
-- the current one, and the API then refuses the call as ambiguous,
-- PGRST203). If that has happened, run the newer files again in order.
--
-- Safe to run more than once.

-- ── 1. Therapists read their sessions through the RPC only ───────────

-- The policy let a therapist select every column of a session assigned
-- to them, including the client's user id, payment references and what
-- was charged. The therapist site and the app use therapist_list_sessions()
-- (security definer), so nothing needs the policy.
drop policy if exists "Therapists read assigned sessions" on public.therapy_requests;

-- ── 2. The hourly brake counts sent requests ─────────────────────────

-- As in 0011, but drafts (awaiting_payment, never sent) don't count, so a
-- few accounts making drafts can't use up the hour for everyone. A request
-- counts from when it was sent to the care team.
create or replace function public.therapy_requests_last_hour()
returns integer
language sql
security definer
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.therapy_requests
  where submitted_at > now() - interval '1 hour'
    and status <> 'awaiting_payment';
$$;

create index if not exists therapy_requests_submitted_idx
  on public.therapy_requests (submitted_at desc)
  where submitted_at is not null;

-- The insert trigger runs as the signed-in client, so authenticated keeps
-- it; nobody signed out needs it.
revoke all on function public.therapy_requests_last_hour() from public, anon, authenticated;
grant execute on function public.therapy_requests_last_hour() to authenticated, service_role;

-- ── 3. Phone notifications: each side on its own ─────────────────────

-- One person's notification about a session. Nothing is queued when
-- there's nobody to send it to: a client whose account was deleted
-- (0035), or a therapist who hasn't signed in yet.
create or replace function public.queue_session_notification(
  r public.therapy_requests,
  p_role text,
  p_kind text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid;
begin
  if p_role = 'client' then
    target := r.user_id;
  else
    target := public.therapist_user_id(r.therapist_id);
    -- Someone booked with themselves hears it once, as the client.
    if target is not distinct from r.user_id then
      return;
    end if;
  end if;
  if target is null then
    return;
  end if;
  insert into public.app_notifications (user_id, kind, data)
  values (target, p_kind, public.session_notification_data(r, p_role));
end;
$$;

-- As in 0010, through the function above.
create or replace function public.queue_session_notifications(
  r public.therapy_requests,
  p_kind text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.queue_session_notification(r, 'client', p_kind);
  perform public.queue_session_notification(r, 'therapist', p_kind);
end;
$$;

-- As in 0010, plus a session moved to another therapist: the one taken
-- off it hears it's cancelled, the one given it hears it's booked.
create or replace function public.notify_session_devices()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reassigned boolean := old.therapist_id is not null
    and new.therapist_id is distinct from old.therapist_id;
begin
  if new.status = 'confirmed' and (
       old.status is distinct from 'confirmed'
       or old.scheduled_at is distinct from new.scheduled_at
       or old.therapist_id is distinct from new.therapist_id) then
    perform public.queue_session_notification(
      new, 'client',
      case when old.status = 'confirmed' then 'session_changed' else 'session_booked' end);
    perform public.queue_session_notification(
      new, 'therapist',
      case when old.status = 'confirmed' and not reassigned
           then 'session_changed' else 'session_booked' end);
  elsif old.status = 'confirmed' and new.status = 'cancelled' then
    perform public.queue_session_notification(new, 'client', 'session_cancelled');
    -- The therapist it was booked with.
    perform public.queue_session_notification(old, 'therapist', 'session_cancelled');
    return new;
  end if;

  if old.status = 'confirmed' and reassigned and new.status <> 'completed' then
    perform public.queue_session_notification(old, 'therapist', 'session_cancelled');
  end if;
  return new;
exception when others then
  raise warning 'session % notification failed: %', new.id, sqlerrm;
  return new;
end;
$$;

-- ── 3 and 4. Session emails ──────────────────────────────────────────

-- As in 0036 (0031, with a late deletion's cancellation worded honestly),
-- plus:
--  * each change has its own idempotency key (the time of the change), so
--    a session moved away and back again is emailed both times;
--  * a therapist given someone else's session gets "New session booked",
--    and the one taken off it gets the cancellation;
--  * a cancellation goes to the therapist it was booked with.
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
    -- the same update.
    therapist_name := coalesce(old_therapist_name, therapist_name);
    therapist_email := coalesce(old_therapist_email, therapist_email);
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

revoke execute on function public.queue_session_notification(public.therapy_requests, text, text) from public, anon, authenticated;
revoke execute on function public.queue_session_notifications(public.therapy_requests, text) from public, anon, authenticated;
revoke execute on function public.notify_session_devices() from public, anon, authenticated;
revoke execute on function public.notify_therapy_session_change() from public, anon, authenticated;

-- ── 5. Ratings ───────────────────────────────────────────────────────

-- Rounded down to the nearest of these, for anyone but an admin.
create or replace function public.therapy_rating_count_bucket(p_count integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select coalesce(max(b), 0)
  from unnest(array[3, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]) b
  where b <= p_count;
$$;

-- As in 0009: client ratings averaged per therapist, shown from three
-- ratings up. For anyone but an admin the count is rounded down (3, 5,
-- 10, 25, …) and, under ten ratings, the average is to the half star, so
-- watching the numbers change doesn't give away what one person said.
-- Ratings from clients who didn't join their session don't count.
create or replace function public.therapist_rating_summaries()
returns table (therapist_id uuid, rating_average numeric, rating_count integer)
language sql
stable
security definer
set search_path = ''
as $$
  with s as (
    select r.therapist_id, avg(rt.rating)::numeric as average, count(*)::integer as n
    from public.therapy_ratings rt
    join public.therapy_requests r on r.id = rt.request_id
    where rt.author_role = 'client'
      and r.therapist_id is not null
      and r.close_reason is distinct from 'client_no_show'
    group by r.therapist_id
  ), me as (
    select public.is_admin() as admin
  )
  select s.therapist_id,
         case
           when me.admin or s.n >= 10 then round(s.average, 1)
           else round(round(s.average * 2) / 2, 1)
         end,
         case when me.admin then s.n else public.therapy_rating_count_bucket(s.n) end
  from s cross join me
  where s.n >= 3 or me.admin;
$$;

-- As in 0009, but a client can't rate a session they didn't join.
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
  -- A client who didn't join has nothing to rate, and a low score for the
  -- therapist who waited for them would be unfair.
  if author = 'client' and req.close_reason = 'client_no_show' then
    raise exception 'You can’t rate a session you didn’t join.' using errcode = '22023';
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

revoke execute on function public.therapy_rating_count_bucket(integer) from public, anon, authenticated;
revoke execute on function public.therapist_rating_summaries() from public, anon;
grant execute on function public.therapist_rating_summaries() to authenticated;
revoke execute on function public.rate_therapy_session(uuid, integer, text, text[]) from public, anon;
grant execute on function public.rate_therapy_session(uuid, integer, text, text[]) to authenticated;

-- ── 6. Pledges belong to one's own habits ────────────────────────────

drop policy if exists "Users create own pledges" on public.recovery_pledges;
create policy "Users create own pledges"
  on public.recovery_pledges for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.recovery_habits h
      where h.id = habit_id and h.user_id = auth.uid()
    )
  );

drop policy if exists "Users update own pledges" on public.recovery_pledges;
create policy "Users update own pledges"
  on public.recovery_pledges for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.recovery_habits h
      where h.id = habit_id and h.user_id = auth.uid()
    )
  );

-- ── 7. Reviewing an application that has just changed ────────────────

-- When the care team was last emailed about each application.
alter table public.therapist_applications
  add column if not exists care_team_emailed_at timestamptz;

-- As in 0032, plus p_reviewed_updated_at: the application's updated_at as
-- the admin saw it. When given, a newer version (sent again while they
-- were checking) is refused rather than approved unseen. Older admin pages
-- that don't send it work as before. The four-argument version goes, so
-- the API has only one to choose from.
drop function if exists public.admin_review_therapist_application(uuid, boolean, text, text[]);
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
      where not (k = any (coalesce(p_checks, '{}')));
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

-- As in 0031, but the care team's email about it goes at most once per
-- applicant in ten minutes (it was one per second sent).
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
  returning a.id into v_id;

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

-- ── 8. A therapist's main licence follows their country ──────────────

-- As in 0034, but a main-licence row is only made for a country there's
-- evidence for: an approved application from that country or an accepted
-- licence document for it. An existing row for the country gets the
-- profile's expiry. Otherwise nothing is made, so changing someone's
-- country doesn't make them licensed there on the old country's papers.
create or replace function public.therapist_sync_primary_licence(p_therapist uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_expires date;
  v_number text;
  v_issuer text;
  v_document uuid;
begin
  select t.country_code, t.licence_expires_on into v_country, v_expires
    from public.therapists t where t.id = p_therapist;
  if v_country is null then
    return;
  end if;

  if exists (select 1 from public.therapist_licences l
              where l.therapist_id = p_therapist and l.country_code = v_country) then
    if v_expires is not null then
      update public.therapist_licences
         set expires_on = v_expires, updated_at = now()
       where therapist_id = p_therapist and country_code = v_country
         and expires_on is distinct from v_expires;
    end if;
    return;
  end if;

  select a.licence_number, a.licence_body into v_number, v_issuer
    from public.therapist_applications a
   where a.therapist_id = p_therapist and a.status = 'approved'
     and a.country_code = v_country
   order by a.updated_at desc
   limit 1;
  if not found then
    select d.id, d.number, d.issuer into v_document, v_number, v_issuer
      from public.therapist_documents d
     where d.therapist_id = p_therapist and d.kind = 'licence'
       and d.status = 'accepted' and d.country_code = v_country
     order by d.reviewed_at desc nulls last
     limit 1;
    if not found then
      return;
    end if;
  end if;
  if v_expires is null then
    return;
  end if;

  insert into public.therapist_licences as l (
    therapist_id, country_code, number, issuer, expires_on, document_id, added_by)
  values (p_therapist, v_country, left(v_number, 80), left(v_issuer, 160), v_expires,
          v_document, 'Main licence')
  on conflict (therapist_id, country_code) do update
  set expires_on = coalesce(excluded.expires_on, l.expires_on),
      number = coalesce(l.number, excluded.number),
      issuer = coalesce(l.issuer, excluded.issuer),
      updated_at = now();
end;
$$;

-- As in 0034, but with no licence in the new country the profile's expiry
-- is cleared rather than kept from the old one: they can't be booked as
-- licensed there until a licence is added for it.
create or replace function public.admin_set_therapist_country(p_therapist_id uuid, p_country text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_country);
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if nullif(trim(coalesce(p_country, '')), '') is not null and v_code is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  update public.therapists t
     set country_code = v_code,
         licence_expires_on = case
           when v_code is null or v_code is not distinct from t.country_code then t.licence_expires_on
           else (select l.expires_on from public.therapist_licences l
                  where l.therapist_id = t.id and l.country_code = v_code)
         end,
         updated_at = now()
   where t.id = p_therapist_id;
  if not found then
    raise exception 'That therapist no longer exists.' using errcode = 'P0002';
  end if;
  return public.therapist_fill_missing_fees();
end;
$$;

revoke execute on function public.therapist_sync_primary_licence(uuid) from public, anon, authenticated;
revoke execute on function public.admin_set_therapist_country(uuid, text) from public, anon;
grant execute on function public.admin_set_therapist_country(uuid, text) to authenticated;

-- ── 9. Site faults: throttled, and nothing new is pushed out ─────────

-- Calls per caller per minute (and emails per caller per hour). Only
-- report_site_error reads and writes it.
create table if not exists public.site_error_throttle (
  bucket text not null,
  window_start timestamptz not null,
  calls integer not null default 0,
  primary key (bucket, window_start)
);
alter table public.site_error_throttle enable row level security;
-- No policies: only the function below uses it.
revoke all on table public.site_error_throttle from public, anon, authenticated;
create index if not exists site_error_throttle_window_idx
  on public.site_error_throttle (window_start);

-- Counts one more call in this window; false once over the limit.
create or replace function public.site_error_take(p_bucket text, p_window interval, p_limit integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_calls integer;
begin
  insert into public.site_error_throttle as t (bucket, window_start, calls)
  values (p_bucket, date_bin(p_window, now(), timestamptz '2000-01-01'), 1)
  on conflict (bucket, window_start) do update set calls = t.calls + 1
  returning t.calls into v_calls;
  return v_calls <= p_limit;
end;
$$;

-- As in 0033, plus:
--  * at most 30 reports a minute from one signed-in person, and 60 a
--    minute from everyone signed out together;
--  * when the log is full, room is made from faults someone has already
--    looked at; faults nobody has seen yet are never pushed out (a new
--    one waits until there's room);
--  * of the six emails an hour, a fault is emailed only when nothing with
--    the same message was emailed in the last hour, one caller gets one
--    an hour, and everyone signed out together at most three.
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
    -- they fill the log, a new one waits.
    if (select count(*) from public.site_errors) >= 2000 then
      delete from public.site_errors e
       where e.fingerprint in (
         select o.fingerprint from public.site_errors o
          where o.status <> 'new'
          order by o.last_seen_at limit 100);
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
          and e.fingerprint <> v_fp
          and regexp_replace(e.message,
                '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9]+', '#', 'g') = v_shape)
     and public.site_error_take('email:' || v_caller, interval '1 hour',
                                case when v_caller = 'anon' then 3 else 1 end) then
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

revoke execute on function public.site_error_take(text, interval, integer) from public, anon, authenticated;
revoke execute on function public.report_site_error(text, text, text, text, jsonb) from public;
grant execute on function public.report_site_error(text, text, text, text, jsonb) to anon, authenticated;

-- ── 10. Practice history, feelings and saves ─────────────────────────

-- A finished session can't be dated in the future; a phone whose clock
-- runs a few minutes ahead is left alone. A later date becomes now.
create or replace function public.practice_sessions_clamp_completed_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.completed_at > now() + interval '5 minutes' then
    new.completed_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists practice_sessions_clamp_completed_at on public.practice_sessions;
create trigger practice_sessions_clamp_completed_at
  before insert or update of completed_at on public.practice_sessions
  for each row execute function public.practice_sessions_clamp_completed_at();

-- Rows already dated ahead would start counting once their date came.
update public.practice_sessions
   set completed_at = now()
 where completed_at > now() + interval '5 minutes';

-- Not valid: rows already there aren't checked, new ones are.
alter table public.practice_sessions
  drop constraint if exists practice_sessions_slug_length;
alter table public.practice_sessions
  add constraint practice_sessions_slug_length
  check (length(slug) between 1 and 200) not valid;
alter table public.practice_sessions
  drop constraint if exists practice_sessions_title_length;
alter table public.practice_sessions
  add constraint practice_sessions_title_length
  check (length(title) <= 300) not valid;
alter table public.session_feelings
  drop constraint if exists session_feelings_slug_length;
alter table public.session_feelings
  add constraint session_feelings_slug_length
  check (length(slug) between 1 and 200) not valid;

-- As in 0026, with an upper bound as well.
create or replace function public.content_popularity(days int default 30)
returns table (kind text, slug text, users bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select ps.kind, ps.slug, count(distinct ps.user_id) as users
  from public.practice_sessions ps
  where ps.completed_at >= now() - make_interval(days => least(greatest(coalesce(content_popularity.days, 30), 1), 365))
    and ps.completed_at <= now() + interval '5 minutes'
  group by ps.kind, ps.slug
  having count(distinct ps.user_id) >= 10
  order by users desc, ps.kind, ps.slug;
$$;

revoke all on function public.content_popularity(int) from public, anon, authenticated;
grant execute on function public.content_popularity(int) to service_role;

-- Far more than anyone keeps for real: 2,000 saved items and 10,000
-- feelings a person. Past that, new ones are refused.
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

drop trigger if exists saved_items_cap on public.saved_items;
create trigger saved_items_cap
  before insert on public.saved_items
  for each row execute function public.user_rows_cap('2000');

drop trigger if exists session_feelings_cap on public.session_feelings;
create trigger session_feelings_cap
  before insert on public.session_feelings
  for each row execute function public.user_rows_cap('10000');

revoke execute on function public.practice_sessions_clamp_completed_at() from public, anon, authenticated;
revoke execute on function public.user_rows_cap() from public, anon, authenticated;

-- ── 11. Therapist photos from this project only ──────────────────────

-- As in 0028, but only this project's storage (zpcfavemnvfhqaxqhmri), not
-- any Supabase project's.
create or replace function public.therapist_photo_ok(p_url text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_url is null
    or (length(p_url) <= 500
        and p_url ~ '^https://zpcfavemnvfhqaxqhmri\.supabase\.co/storage/v1/object/public/therapist-photos/[A-Za-z0-9/_.?=-]+$');
$$;

revoke execute on function public.therapist_photo_ok(text) from public, anon, authenticated;

-- ── 13. Overloads left by re-running older files ─────────────────────

-- Each was replaced by a version with more arguments; re-running the file
-- that made it puts it back beside the current one. None exists after
-- running the files in order.
drop function if exists public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text);
drop function if exists public.therapist_submit_application(text, text, text, text, text, text, text, text[], text[], integer, text, date, text, text, text, date, text, text, text, text);
drop function if exists public.admin_review_therapist_application(uuid, boolean, text);
drop function if exists public.therapist_submit_document(text, text, date, text, text);
drop function if exists public.therapy_detect_country(text, text, text, text);
