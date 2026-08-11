-- Therapy booking schema: session requests submitted from the app.
-- Users can create and cancel requests; confirming, scheduling, and
-- completing them happens from the dashboard (service role bypasses RLS).
-- Run in Supabase dashboard → SQL Editor.

create table if not exists public.therapy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  topic text not null,
  availability text[] not null default '{}',
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'completed', 'cancelled')),
  is_free_session boolean not null default false,
  scheduled_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists therapy_requests_user_created_idx
  on public.therapy_requests (user_id, created_at desc);

alter table public.therapy_requests enable row level security;

drop policy if exists "Users read own therapy requests" on public.therapy_requests;
create policy "Users read own therapy requests"
  on public.therapy_requests for select using (auth.uid() = user_id);

drop policy if exists "Users create own therapy requests" on public.therapy_requests;
create policy "Users create own therapy requests"
  on public.therapy_requests for insert
  with check (auth.uid() = user_id and status = 'pending');

-- The only self-service update is cancelling a not-yet-confirmed request.
drop policy if exists "Users cancel own therapy requests" on public.therapy_requests;
create policy "Users cancel own therapy requests"
  on public.therapy_requests for update
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status = 'cancelled');
