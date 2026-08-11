-- Recovery tools schema: commitments (habits being quit), daily pledges,
-- and craving logs. Run in Supabase dashboard → SQL Editor.

-- ── Commitments ──────────────────────────────────────────────────
create table if not exists public.recovery_habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  day_one date not null default (now()::date),
  best_streak_days int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.recovery_habits enable row level security;

drop policy if exists "Users read own habits" on public.recovery_habits;
create policy "Users read own habits"
  on public.recovery_habits for select using (auth.uid() = user_id);
drop policy if exists "Users create own habits" on public.recovery_habits;
create policy "Users create own habits"
  on public.recovery_habits for insert with check (auth.uid() = user_id);
drop policy if exists "Users update own habits" on public.recovery_habits;
create policy "Users update own habits"
  on public.recovery_habits for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users delete own habits" on public.recovery_habits;
create policy "Users delete own habits"
  on public.recovery_habits for delete using (auth.uid() = user_id);

-- ── Daily pledges: one per habit per day ─────────────────────────
create table if not exists public.recovery_pledges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  habit_id uuid not null references public.recovery_habits (id) on delete cascade,
  pledge_date date not null default (now()::date),
  created_at timestamptz not null default now(),
  unique (habit_id, pledge_date)
);

alter table public.recovery_pledges enable row level security;

drop policy if exists "Users read own pledges" on public.recovery_pledges;
create policy "Users read own pledges"
  on public.recovery_pledges for select using (auth.uid() = user_id);
drop policy if exists "Users create own pledges" on public.recovery_pledges;
create policy "Users create own pledges"
  on public.recovery_pledges for insert with check (auth.uid() = user_id);
drop policy if exists "Users update own pledges" on public.recovery_pledges;
create policy "Users update own pledges"
  on public.recovery_pledges for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users delete own pledges" on public.recovery_pledges;
create policy "Users delete own pledges"
  on public.recovery_pledges for delete using (auth.uid() = user_id);

-- ── Craving logs ─────────────────────────────────────────────────
create table if not exists public.craving_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  intensity smallint not null check (intensity between 1 and 5),
  trigger_kind text not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists craving_logs_user_created_idx
  on public.craving_logs (user_id, created_at desc);

alter table public.craving_logs enable row level security;

drop policy if exists "Users read own cravings" on public.craving_logs;
create policy "Users read own cravings"
  on public.craving_logs for select using (auth.uid() = user_id);
drop policy if exists "Users create own cravings" on public.craving_logs;
create policy "Users create own cravings"
  on public.craving_logs for insert with check (auth.uid() = user_id);
drop policy if exists "Users delete own cravings" on public.craving_logs;
create policy "Users delete own cravings"
  on public.craving_logs for delete using (auth.uid() = user_id);
