-- 0024: How people feel after a session.
--
-- A finished meditation or breathing session now ends by asking "Compared
-- with when you started, how do you feel?" — better, about the same, or
-- worse. Kept so people can see what helps them ("you felt better after 8
-- of your last 10 sessions"), so suggestions can lean towards what works,
-- and so we can show the app does something.
--
-- It replaces the mood faces the close-out used to show, which overwrote
-- that day's check-in with a post-session mood and skewed mood history.
--
-- Paste-run this in the Supabase dashboard → SQL Editor. Until it runs the
-- app keeps answers on the device only.

create table if not exists public.session_feelings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('meditation', 'breathing', 'sound')),
  slug text not null,
  -- -1 worse, 0 about the same, 1 better.
  feeling smallint not null check (feeling between -1 and 1),
  created_at timestamptz not null default now()
);

create index if not exists session_feelings_user_created_idx
  on public.session_feelings (user_id, created_at desc);

alter table public.session_feelings enable row level security;

drop policy if exists "Users read own feelings" on public.session_feelings;
create policy "Users read own feelings"
  on public.session_feelings for select
  using (auth.uid() = user_id);

drop policy if exists "Users create own feelings" on public.session_feelings;
create policy "Users create own feelings"
  on public.session_feelings for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own feelings" on public.session_feelings;
create policy "Users delete own feelings"
  on public.session_feelings for delete
  using (auth.uid() = user_id);
