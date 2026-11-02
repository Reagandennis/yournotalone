-- 0025: Saved items, on the account.
--
-- Hearted items used to live only on the phone, so a new phone (or a
-- reinstall) started with nothing saved. Now each save is a row here and
-- the app keeps its own copy in step: saves made offline are sent once
-- there's a connection, and an item unsaved on one phone disappears from
-- the others (see lib/discover/saved_store.dart).
--
-- item_id is the content id (`sound:Rainfall`, or a slug for newer
-- items) — the same ids the catalogue keeps forever, so a renamed item
-- stays saved. Deleting the account deletes its saves.
--
-- Paste-run this in the Supabase dashboard → SQL Editor. Safe to re-run.
-- Until it runs the app keeps saves on the device only, as before.

create table if not exists public.saved_items (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id text not null check (length(item_id) between 1 and 200),
  saved_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create index if not exists saved_items_user_saved_idx
  on public.saved_items (user_id, saved_at desc);

alter table public.saved_items enable row level security;

drop policy if exists "Users read own saves" on public.saved_items;
create policy "Users read own saves"
  on public.saved_items for select
  using (auth.uid() = user_id);

drop policy if exists "Users create own saves" on public.saved_items;
create policy "Users create own saves"
  on public.saved_items for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own saves" on public.saved_items;
create policy "Users delete own saves"
  on public.saved_items for delete
  using (auth.uid() = user_id);
