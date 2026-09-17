-- A session can't be cancelled from the app once it has started.
--
-- The app-side cancel rule (0009, then 0010) only checked that the session
-- wasn't paid. A confirmed free session could be cancelled after it had
-- happened — attend, cancel before the therapist taps Finish — and since
-- the free first session is "no request that isn't cancelled", the next
-- request was free again. Repeatable forever.
--
-- Now a confirmed session is locked to the app from the moment its call
-- opens (10 minutes before the start, as in session-token and the app's
-- Join button). From then on only the care team can cancel it, from the
-- dashboard, and they decide whether the free session was used.
--
-- Pending requests (not yet matched) can still be cancelled at any time:
-- nothing was delivered, so nothing is consumed.
--
-- Refusals raise SQLSTATE P0001 with a message the app shows as is.
-- Run in Supabase dashboard → SQL Editor (safe to re-run).

-- Same as in 0010, plus the cutoff.
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
  if old.status = 'confirmed'
     and old.scheduled_at is not null
     and old.scheduled_at - interval '10 minutes' <= now() then
    raise exception 'This session has already started, so it can''t be cancelled from the app. If something went wrong, reply to our email and we''ll sort it out.'
      using errcode = 'P0001';
  end if;
  new := old;
  new.status := 'cancelled';
  new.cancelled_at := now();
  return new;
end;
$$;
