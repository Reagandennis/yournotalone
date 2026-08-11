-- Journal & daily-mood schema for Δεν είσαι μόνος.
-- Run this once in the Supabase dashboard → SQL Editor → New query → Run.

create extension if not exists moddatetime with schema extensions;

-- ── Journal entries ──────────────────────────────────────────────
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists journal_entries_user_created_idx
  on public.journal_entries (user_id, created_at desc);

drop trigger if exists journal_entries_updated_at on public.journal_entries;
create trigger journal_entries_updated_at
  before update on public.journal_entries
  for each row execute procedure extensions.moddatetime(updated_at);

alter table public.journal_entries enable row level security;

drop policy if exists "Users read own entries" on public.journal_entries;
create policy "Users read own entries"
  on public.journal_entries for select
  using (auth.uid() = user_id);

drop policy if exists "Users create own entries" on public.journal_entries;
create policy "Users create own entries"
  on public.journal_entries for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own entries" on public.journal_entries;
create policy "Users update own entries"
  on public.journal_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own entries" on public.journal_entries;
create policy "Users delete own entries"
  on public.journal_entries for delete
  using (auth.uid() = user_id);

-- ── Daily moods: one row per user per day ────────────────────────
create table if not exists public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mood text not null check (mood in ('awful', 'low', 'okay', 'good', 'great')),
  mood_score smallint not null check (mood_score between 1 and 5),
  entry_date date not null default (now()::date),
  created_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

alter table public.mood_entries enable row level security;

drop policy if exists "Users read own moods" on public.mood_entries;
create policy "Users read own moods"
  on public.mood_entries for select
  using (auth.uid() = user_id);

drop policy if exists "Users create own moods" on public.mood_entries;
create policy "Users create own moods"
  on public.mood_entries for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own moods" on public.mood_entries;
create policy "Users update own moods"
  on public.mood_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own moods" on public.mood_entries;
create policy "Users delete own moods"
  on public.mood_entries for delete
  using (auth.uid() = user_id);
