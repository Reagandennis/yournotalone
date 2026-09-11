-- 0007: Practice history.
--
-- Until now the app kept moods, journal entries and recovery data, but
-- nothing recorded that anyone had actually *done* anything: a finished
-- meditation, a breathing session or an hour of sounds left no trace. So
-- there was no streak, no minute s practised, and nothing to come back to.
--
-- One row per completed session. Deliberately small — the catalogue lives
-- in the app, and only the slug is stored, so renaming a session's copy
-- doesn't rewrite anyone's history.
--
-- Paste-run this in the Supabase dashboard → SQL Editor.

create table if not exists public.practice_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('meditation', 'breathing', 'sound')),
  -- Stable identifier for the catalogue entry (its title today).
  slug text not null,
  -- Copy of the title as it was, so old history still reads correctly if
  -- the catalogue changes.
  title text not null,
  minutes numeric(6, 2) not null check (minutes >= 0),
  completed_at timestamptz not null default now()
);

create index if not exists practice_sessions_user_completed_idx
  on public.practice_sessions (user_id, completed_at desc);

alter table public.practice_sessions enable row level security;

drop policy if exists "Users read own sessions" on public.practice_sessions;
create policy "Users read own sessions"
  on public.practice_sessions for select
  using (auth.uid() = user_id);

drop policy if exists "Users create own sessions" on public.practice_sessions;
create policy "Users create own sessions"
  on public.practice_sessions for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own sessions" on public.practice_sessions;
create policy "Users delete own sessions"
  on public.practice_sessions for delete
  using (auth.uid() = user_id);
