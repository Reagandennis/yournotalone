-- 0006: Account deletion.
--
-- The app can't remove an auth.users row on its own — that needs the
-- service_role key, which never ships in a client. So deletion runs in
-- two parts:
--
--   1. The app writes a row here, so the request is recorded even if the
--      next step fails.
--   2. The `delete-account` Edge Function deletes the auth user with
--      service_role; every table below cascades from auth.users, so the
--      user's data goes with it.
--
-- If the function is ever unavailable, the rows left in `status = 'pending'`
-- are the work queue — see supabase/account_ops.sql.
--
-- Paste-run this in the Supabase dashboard → SQL Editor.

create table if not exists public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Kept so a completed request can still be audited after the auth user
  -- (and this row, by cascade) is gone from a backup restore.
  user_email text,
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists deletion_requests_pending_idx
  on public.deletion_requests (requested_at)
  where status = 'pending';

alter table public.deletion_requests enable row level security;

-- A user may file their own request and see its progress. Nobody may edit
-- or withdraw one from the client — only the function (service_role,
-- which bypasses RLS) closes a request out.
drop policy if exists "Users create own deletion request" on public.deletion_requests;
create policy "Users create own deletion request"
  on public.deletion_requests for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users read own deletion request" on public.deletion_requests;
create policy "Users read own deletion request"
  on public.deletion_requests for select
  using (auth.uid() = user_id);
