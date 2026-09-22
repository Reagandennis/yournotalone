-- No double-booking a therapist, and cheap cron scans.
--
-- Double-booking. admin_match_therapy_request() checked for an overlapping
-- confirmed session and then wrote the booking — two statements, and the
-- only lock it held was on the request being matched. Two admins matching
-- two different requests to the same therapist at the same time both ran
-- the check before either had written, both found nothing, and both
-- booked. Now:
--   • The function takes a transaction-scoped advisory lock on the
--     therapist before it looks, so a second admin waits for the first to
--     finish and then sees their booking (and gets the readable error).
--   • An exclusion constraint on (therapist, session span) among confirmed
--     sessions guarantees it regardless of who writes — the function, the
--     dashboard, or a future migration. Its GiST index also serves the
--     function's own overlap check.
--
-- Cron scans. send_session_reminders() runs every minute and
-- close_out_elapsed_sessions() every 15 minutes; both look for confirmed
-- sessions by scheduled_at, and the table had no index that fit, so each
-- run read every request ever made. A partial index over the (few)
-- confirmed sessions makes both a handful of page reads.
--
-- Before running: if the constraint refuses to be created, two confirmed
-- sessions already overlap. Find them with
--   select a.id, b.id, a.therapist_id, a.scheduled_at, b.scheduled_at
--   from public.therapy_requests a join public.therapy_requests b
--     on a.therapist_id = b.therapist_id and a.id < b.id
--   where a.status = 'confirmed' and b.status = 'confirmed'
--     and public.session_span(a.scheduled_at, a.duration_minutes)
--      && public.session_span(b.scheduled_at, b.duration_minutes);
-- and move one of each pair (admin_match_therapy_request) first.
--
-- Run in Supabase dashboard → SQL Editor, after 0016.

create extension if not exists btree_gist with schema extensions;

-- The time a session occupies. Declared immutable, which it is: a whole
-- number of minutes never depends on the time zone (unlike days or
-- months), and an index expression has to be.
create or replace function public.session_span(
  p_start timestamptz,
  p_minutes integer
)
returns tstzrange
language sql
immutable
parallel safe
set search_path = ''
as $$
  select tstzrange(p_start, p_start + make_interval(mins => p_minutes), '[)');
$$;
revoke execute on function public.session_span(timestamptz, integer) from public, anon, authenticated;

alter table public.therapy_requests
  drop constraint if exists therapy_requests_no_double_booking;
alter table public.therapy_requests
  add constraint therapy_requests_no_double_booking
  exclude using gist (
    therapist_id extensions.gist_uuid_ops with =,
    public.session_span(scheduled_at, duration_minutes) with &&
  )
  where (status = 'confirmed');

-- What the reminder and close-out crons walk: confirmed sessions by time.
create index if not exists therapy_requests_confirmed_schedule_idx
  on public.therapy_requests (scheduled_at)
  where status = 'confirmed';

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

  -- One admin at a time per therapist's diary, until this transaction
  -- ends: the check below and the write are then one step.
  perform pg_advisory_xact_lock(
    hashtext('therapist-schedule'), hashtext(p_therapist_id::text));

  if exists (
    select 1 from public.therapy_requests r
    where r.therapist_id = p_therapist_id
      and r.status = 'confirmed'
      and r.id <> p_request_id
      and public.session_span(r.scheduled_at, r.duration_minutes)
          && public.session_span(p_scheduled_at, p_duration_minutes)
  ) then
    raise exception 'That therapist already has a session at that time.'
      using errcode = '23P01';
  end if;

  begin
    update public.therapy_requests
    set therapist_id = p_therapist_id,
        scheduled_at = p_scheduled_at,
        duration_minutes = p_duration_minutes,
        status = 'confirmed',
        confirmed_at = coalesce(confirmed_at, now())
    where id = p_request_id;
  exception when exclusion_violation then
    -- Only reachable by a writer that skipped the lock; same answer.
    raise exception 'That therapist already has a session at that time.'
      using errcode = '23P01';
  end;
end;
$$;
revoke execute on function public.admin_match_therapy_request(uuid, uuid, timestamptz, integer) from public, anon;
grant execute on function public.admin_match_therapy_request(uuid, uuid, timestamptz, integer) to authenticated;
