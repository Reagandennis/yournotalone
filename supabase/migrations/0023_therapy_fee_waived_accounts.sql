-- Accounts whose therapy sessions are always free.
--
-- Since 0019 every request starts as a draft that has to be paid for; the
-- dashboard's "Waive fee" works one request at a time. An account with
-- `therapy_fee_waived` in its app metadata now skips that: each request it
-- sends is saved as pending with the fee waived, so it reaches the care
-- team (and the request emails go out) straight away. App metadata can
-- only be written in the SQL Editor or with the service role, never by
-- the app or its user — the same as premium_comp (0014).
--
-- Grant or remove it with supabase/account_ops.sql, section 5. Builds on
-- 0019. Run in Supabase dashboard → SQL Editor (safe to re-run).

-- ── Whether the signed-in account's fee is waived ────────────────────

-- Reads auth.users, which the app's role can't, and only ever for the
-- caller's own account.
create or replace function public.therapy_fee_waived()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (u.raw_app_meta_data ->> 'therapy_fee_waived')::boolean
       from auth.users u
      where u.id = auth.uid()),
    false);
$$;

revoke all on function public.therapy_fee_waived() from public, anon;
grant execute on function public.therapy_fee_waived() to authenticated;

-- ── Policy: such a request is inserted already pending ───────────────

-- The insert trigger decides the status; this only lets its answer through.
drop policy if exists "Users create own therapy requests" on public.therapy_requests;
create policy "Users create own therapy requests"
  on public.therapy_requests for insert
  with check (auth.uid() = user_id
              and (status = 'awaiting_payment'
                   or (status = 'pending' and payment_status = 'waived')));

-- ── Insert: as in 0019, plus the waiver ──────────────────────────────

create or replace function public.therapy_requests_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.topic := trim(new.topic);
  new.note := nullif(trim(new.note), '');

  if current_user in ('anon', 'authenticated') then
    new.status := 'awaiting_payment';
    new.therapist_id := null;
    new.scheduled_at := null;
    new.duration_minutes := 50;
    new.payment_ref := null;
    new.paid_at := null;
    new.confirmed_at := null;
    new.completed_at := null;
    new.cancelled_at := null;
    new.client_summary := null;
    new.close_reason := null;
    new.submitted_at := null;
    new.payment_status := 'unpaid';
    new.created_at := now();

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
        and r.submitted_at > now() - interval '24 hours'
    ) >= public.therapy_requests_daily_limit() then
      raise exception 'That''s as many requests as we can take in a day. Please try again tomorrow, or reply to our email if it''s urgent.'
        using errcode = 'P0001';
    end if;

    -- Drafts are cheap, but not free to make without limit.
    if (
      select count(*) from public.therapy_requests r
      where r.user_id = new.user_id
        and r.created_at > now() - interval '24 hours'
    ) >= public.therapy_requests_daily_limit() * 4 then
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

    -- The newest draft is the one they mean; an older unpaid one goes.
    -- A purchase that was meant for it is never lost: the Edge Function
    -- attaches the oldest unused purchase to whichever draft is paid next.
    update public.therapy_requests
    set status = 'cancelled'
    where user_id = new.user_id and status = 'awaiting_payment';
  end if;

  -- Every session is priced. Only the dashboard (which bypasses the block
  -- above) can insert one with the fee already waived.
  new.is_free_session := false;
  new.price_cents := public.therapy_session_price_cents();
  new.currency := 'USD';
  if new.payment_status not in ('paid', 'waived') then
    new.payment_status := 'unpaid';
  end if;

  -- An account the care team has waived the fee for skips the draft: the
  -- request goes straight to them, already marked waived.
  if current_user in ('anon', 'authenticated')
     and public.therapy_fee_waived() then
    new.payment_status := 'waived';
    new.status := 'pending';
    new.submitted_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists therapy_requests_before_insert on public.therapy_requests;
create trigger therapy_requests_before_insert
  before insert on public.therapy_requests
  for each row execute function public.therapy_requests_before_insert();

-- ── reaganowiti8@gmail.com ───────────────────────────────────────────

update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                           || '{"therapy_fee_waived": true}'::jsonb
 where lower(email) = 'reaganowiti8@gmail.com';

-- Anything of theirs still waiting on a payment: a draft moves to pending
-- (0019's update trigger), a matched session just stops asking.
update public.therapy_requests r
   set payment_status = 'waived'
  from auth.users u
 where u.id = r.user_id
   and lower(u.email) = 'reaganowiti8@gmail.com'
   and r.payment_status = 'unpaid'
   and r.status in ('awaiting_payment', 'pending', 'confirmed');

-- Check:
-- select u.email, u.raw_app_meta_data ->> 'therapy_fee_waived' as waived,
--        r.status, r.payment_status, r.created_at
--   from auth.users u
--   left join public.therapy_requests r on r.user_id = u.id
--  where lower(u.email) = 'reaganowiti8@gmail.com'
--  order by r.created_at desc;
