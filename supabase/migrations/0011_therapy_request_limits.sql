-- Bounds on therapy requests.
--
-- Until now any signed-in token could insert as many requests as it liked,
-- of any size, straight through the REST API — the app only hides the form
-- while a request is open, nothing stopped a script. Every insert sends two
-- emails (0008), so one loop could burn the Resend quota and flood the care
-- inbox. This migration puts the limits where they belong, in the database:
--
--   • Sizes: topic ≤ 100 characters, note ≤ 1000, at most 8 availability
--     slots of ≤ 40 characters each. The app already caps the note at 500
--     and picks the topic and slots from fixed lists, so real requests are
--     nowhere near these.
--   • One open request at a time: a second request while one is pending
--     or confirmed is refused. (Cancel it first — the app already works
--     this way.)
--   • At most 5 requests per person per rolling 24 hours, cancelled ones
--     included, so cancel-and-rebook loops are bounded too.
--   • A global brake: if more than 60 requests arrive in an hour from the
--     app, further ones are refused until it calms down. Real volume is
--     far below that; only a flood across many accounts gets there.
--
-- The dashboard and the security-definer functions run as the owner and
-- bypass the per-person and global caps, as they do the rest of the
-- before-insert rules. The size checks apply to everyone.
--
-- Refusals are raised with SQLSTATE P0001 and a message written for people;
-- the app shows it as is.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run).

-- ── Sizes ──────────────────────────────────────────────────────────

-- Availability is an array, and a check constraint can't contain a
-- subquery, so the per-element check lives in an immutable helper.
create or replace function public.therapy_availability_ok(slots text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select slots is not null
    and cardinality(slots) <= 8
    and coalesce(
      (select bool_and(s is not null and length(s) between 1 and 40)
         from unnest(slots) as s),
      true);
$$;

-- Nothing in the app can have produced rows over these limits, but trim
-- anything that somehow is so the constraints can be added cleanly.
update public.therapy_requests set topic = left(topic, 100)
  where length(topic) > 100;
update public.therapy_requests set note = left(note, 1000)
  where length(note) > 1000;
update public.therapy_requests
  set availability = (
    select coalesce(array_agg(left(s, 40)), '{}')
    from unnest(availability[1:8]) as s
    where s is not null and s <> '')
  where not public.therapy_availability_ok(availability);

alter table public.therapy_requests
  drop constraint if exists therapy_requests_topic_length_check,
  drop constraint if exists therapy_requests_note_length_check,
  drop constraint if exists therapy_requests_availability_check;
alter table public.therapy_requests
  add constraint therapy_requests_topic_length_check
    check (length(topic) between 1 and 100),
  add constraint therapy_requests_note_length_check
    check (note is null or length(note) <= 1000),
  add constraint therapy_requests_availability_check
    check (public.therapy_availability_ok(availability));

-- ── Caps ───────────────────────────────────────────────────────────

create or replace function public.therapy_requests_daily_limit()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 5;
$$;

create or replace function public.therapy_requests_hourly_limit()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 60;
$$;

-- How many requests the whole app has made in the last hour. Security
-- definer because the caller can only see their own rows under RLS, and
-- the global brake needs to count everyone's. It returns a number and
-- nothing else.
create or replace function public.therapy_requests_last_hour()
returns integer
language sql
security definer
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.therapy_requests
  where created_at > now() - interval '1 hour';
$$;

revoke all on function public.therapy_requests_last_hour() from public;
grant execute on function public.therapy_requests_last_hour() to authenticated;

create index if not exists therapy_requests_created_idx
  on public.therapy_requests (created_at desc);

-- Same as in 0009, plus the caps for requests made from the app.
create or replace function public.therapy_requests_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.topic := trim(new.topic);
  new.note := nullif(trim(new.note), '');

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

    -- One person at a time, so two requests fired together can't both
    -- slip past the checks below. Released when the transaction ends.
    perform pg_advisory_xact_lock(
      hashtext('therapy_requests:' || new.user_id::text));

    if exists (
      select 1 from public.therapy_requests r
      where r.user_id = new.user_id
        and r.status in ('pending', 'confirmed')
    ) then
      raise exception 'You already have a session on the way. Cancel it first if you need to change something.'
        using errcode = 'P0001';
    end if;

    if (
      select count(*) from public.therapy_requests r
      where r.user_id = new.user_id
        and r.created_at > now() - interval '24 hours'
    ) >= public.therapy_requests_daily_limit() then
      raise exception 'That''s as many requests as we can take in a day. Please try again tomorrow, or reply to our email if it''s urgent.'
        using errcode = 'P0001';
    end if;

    if public.therapy_requests_last_hour()
       >= public.therapy_requests_hourly_limit() then
      raise warning 'therapy requests: hourly limit reached, refusing user %',
        new.user_id;
      raise exception 'We''re getting a lot of requests right now. Please try again in a little while.'
        using errcode = 'P0001';
    end if;
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

drop trigger if exists therapy_requests_before_insert on public.therapy_requests;
create trigger therapy_requests_before_insert
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_before_insert();
