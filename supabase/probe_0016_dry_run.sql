begin;
-- Sessions close themselves out when nobody does it by hand.
--
-- A confirmed session only ever became "completed" when its therapist
-- tapped Finish. If nobody did — the session happened and was forgotten,
-- the client never showed, the therapist never showed, or the client never
-- paid — the session stayed confirmed forever. The app hides the booking
-- form while a request is pending or confirmed, and 0011 refuses a second
-- one, so that client could never book again. Since 0015 they can't cancel
-- a confirmed session after its call opens either, so all they saw was
-- "If it didn't happen, contact us", indefinitely.
--
-- Now:
--   • session-token records who actually asked to join the call
--     (client_joined_at, therapist_joined_at). A token is only issued when
--     someone taps Join inside the call window, so this is as close to
--     "showed up" as the server can see.
--   • Every 15 minutes, close_out_elapsed_sessions() looks at confirmed
--     sessions that ended more than two hours ago (time for the therapist
--     to finish it properly first) and closes each one:
--       – never paid            → cancelled, close_reason 'unpaid'
--       – therapist joined,
--         client joined         → completed, 'auto_completed'
--       – therapist joined,
--         client did not        → completed, 'client_no_show'
--                                 (the session was delivered: a free first
--                                 session counts as used, a paid one stays
--                                 paid)
--       – therapist did not
--         join, client did      → cancelled, 'therapist_no_show'
--       – nobody joined         → cancelled, 'nobody_joined'
--     A cancelled session hands a free first session back (the unique
--     index in 0009 only counts non-cancelled rows, and the before-insert
--     rule computes "free" the same way). A paid one that's cancelled needs
--     a refund, so the care team is emailed about every auto-closure that
--     isn't a plain auto-complete; the client gets the usual cancellation
--     email and app notification from the 0009/0010 triggers.
--   • Therapists tapping Finish on a session the sweep already cancelled
--     get told why, instead of "Only a confirmed session can be completed."
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then redeploy:
--   supabase functions deploy session-token

alter table public.therapy_requests
  add column if not exists client_joined_at timestamptz,
  add column if not exists therapist_joined_at timestamptz,
  add column if not exists close_reason text;

alter table public.therapy_requests
  drop constraint if exists therapy_requests_close_reason_check;
alter table public.therapy_requests
  add constraint therapy_requests_close_reason_check
  check (close_reason is null or close_reason in (
    'auto_completed', 'client_no_show', 'therapist_no_show',
    'nobody_joined', 'unpaid'));

-- ── The sweep ────────────────────────────────────────────────────────

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
  closed integer := 0;
  new_status text;
  reason text;
  client_email text;
  client_name text;
  therapist_name text;
  when_text text;
  what text;
  todo text;
begin
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
    where id = r.id;
    closed := closed + 1;

    if reason = 'auto_completed' then
      continue;
    end if;

    -- The care team hears about anything that may need a hand.
    begin
      select u.email::text,
             nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                                  u.raw_user_meta_data ->> 'name', '')), '')
        into client_email, client_name
        from auth.users u where u.id = r.user_id;
      select t.full_name into therapist_name
        from public.therapists t where t.id = r.therapist_id;
      when_text := public.email_session_time(r.scheduled_at);

      what := case reason
        when 'client_no_show' then
          'The therapist joined the call but the client never did. The '
          || 'session counts as delivered: it is marked completed and '
          || case when r.is_free_session then 'their free first session is used.'
                  else 'stays paid.' end
        when 'therapist_no_show' then
          'The client joined the call but the therapist never did. The '
          || 'session is cancelled'
          || case when r.is_free_session then ' and their free first session is returned.'
                  else '.' end
        when 'nobody_joined' then
          'Neither the client nor the therapist joined the call. The session '
          || 'is cancelled'
          || case when r.is_free_session then ' and their free first session is returned.'
                  else '.' end
        else
          'The client never paid for it. The session is cancelled so they can '
          || 'book again.'
      end;
      todo := case
        when new_status = 'cancelled' and r.payment_status = 'paid' then
          'They had paid $' || (r.price_cents / 100)
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

revoke all on function public.close_out_elapsed_sessions() from public, anon, authenticated;

select cron.unschedule(jobid)
  from cron.job where jobname = 'therapy-session-close-out';
select cron.schedule(
  'therapy-session-close-out',
  '*/15 * * * *',
  $$select public.close_out_elapsed_sessions()$$
);

-- ── Finish after the sweep ───────────────────────────────────────────

-- Same as in 0009, with a clearer refusal for a session the sweep closed.
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
  if req.status = 'cancelled' and req.close_reason is not null then
    raise exception 'This session was closed automatically because %. If it did go ahead, tell the care team and they’ll sort it out.',
      case req.close_reason
        when 'unpaid' then 'the client never paid'
        when 'therapist_no_show' then 'you didn’t join the call'
        else 'nobody joined the call'
      end
      using errcode = '22023';
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

-- ── What the app reads ───────────────────────────────────────────────

-- The client's own rows come straight from the table under RLS, so the
-- new columns are already visible to them.

-- Same as in 0012, plus close_reason and who joined. The return type
-- changes, so the function is dropped first.
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
         r.refunded_at,
         r.therapist_id, t.full_name,
         r.user_id,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), ''),
         u.email::text,
         r.client_summary, r.completed_at,
         r.close_reason, r.client_joined_at, r.therapist_joined_at,
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

grant execute on function public.admin_list_therapy_requests() to authenticated;

-- Same as in 0009, plus close_reason and whether the client joined.
drop function if exists public.therapist_list_sessions();
create function public.therapist_list_sessions()
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
  close_reason text,
  client_joined_at timestamptz,
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
         r.close_reason, r.client_joined_at,
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

grant execute on function public.therapist_list_sessions() to authenticated;
-- Exercise the sweep on synthetic rows, then throw everything away.
do $$
declare
  uid uuid;
  tid uuid;
  n integer;
  rows text;
begin
  select id into uid from auth.users order by created_at limit 1;
  select id into tid from public.therapists limit 1;
  if uid is null or tid is null then
    rows := 'no user/therapist to test with (users=' || coalesce(uid::text,'none') || ', therapist=' || coalesce(tid::text,'none') || ')';
  else
    -- Five confirmed sessions that ended 3 hours ago, one per outcome.
    insert into public.therapy_requests
      (user_id, topic, availability, status, is_free_session, therapist_id,
       scheduled_at, duration_minutes, price_cents, payment_status,
       client_joined_at, therapist_joined_at)
    values
      (uid, 'probe unpaid', '{}', 'confirmed', false, tid, now() - interval '4 hours', 50, 2000, 'unpaid', null, null),
      (uid, 'probe both', '{}', 'confirmed', false, tid, now() - interval '4 hours', 50, 2000, 'paid', now() - interval '4 hours', now() - interval '4 hours'),
      (uid, 'probe client no-show', '{}', 'confirmed', false, tid, now() - interval '4 hours', 50, 2000, 'paid', null, now() - interval '4 hours'),
      (uid, 'probe therapist no-show', '{}', 'confirmed', false, tid, now() - interval '4 hours', 50, 2000, 'paid', now() - interval '4 hours', null),
      (uid, 'probe nobody', '{}', 'confirmed', false, tid, now() - interval '4 hours', 50, 2000, 'paid', null, null),
      (uid, 'probe too recent', '{}', 'confirmed', false, tid, now() - interval '1 hour', 50, 2000, 'paid', null, null);
    select public.close_out_elapsed_sessions() into n;
    select string_agg(topic || ' => ' || status || '/' || coalesce(close_reason, '-'), '; ' order by topic)
      into rows from public.therapy_requests where topic like 'probe %';
    rows := 'closed ' || n || ' :: ' || coalesce(rows, '(no probe rows)');
  end if;
  raise exception 'marker %', rows;
end $$;
