-- 0027: Admins add and remove other admins from the admin page.
--
-- public.admins becomes the one list of admins. Being on it gives both
-- kinds of access: the therapy tools (the admin_* functions already check
-- it) and content editing, which the admin Worker reads from the
-- content_admin flag in app_metadata. A trigger on auth.users keeps that
-- flag equal to the list, so an email can be added before its account
-- exists: the flag is set once the account's email is confirmed.
--
-- A change to the flag reaches the admin page with the next session token,
-- so within the hour (or at once after signing out and in again). The
-- therapy tools see it straight away.
--
-- Paste-run this in the Supabase dashboard → SQL Editor. Safe to re-run.

-- Everyone who can edit content today stays an admin.
insert into public.admins (email)
select lower(u.email)
from auth.users u
where u.raw_app_meta_data ->> 'content_admin' = 'true'
  and u.email is not null
  and u.email_confirmed_at is not null
on conflict (email) do nothing;

-- content_admin follows public.admins, for confirmed emails only.
create or replace function public.sync_content_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email_confirmed_at is not null
     and exists (select 1 from public.admins a where a.email = lower(new.email)) then
    new.raw_app_meta_data :=
      coalesce(new.raw_app_meta_data, '{}'::jsonb) || '{"content_admin": true}'::jsonb;
  elsif new.raw_app_meta_data ? 'content_admin' then
    new.raw_app_meta_data := new.raw_app_meta_data - 'content_admin';
  end if;
  return new;
end;
$$;

drop trigger if exists sync_content_admin on auth.users;
create trigger sync_content_admin
  before insert or update of email, email_confirmed_at, raw_app_meta_data
  on auth.users
  for each row execute function public.sync_content_admin();

-- Re-run the trigger for every account that has, or should have, the flag.
update auth.users u
set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
where u.raw_app_meta_data ? 'content_admin'
   or exists (select 1 from public.admins a where a.email = lower(u.email));

create or replace function public.admin_list_admins()
returns table (
  email text,
  added_at timestamptz,
  has_account boolean,
  confirmed boolean,
  last_sign_in_at timestamptz,
  is_you boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can see the admin list.' using errcode = '42501';
  end if;
  return query
    select a.email, a.created_at, u.id is not null, u.email_confirmed_at is not null,
           u.last_sign_in_at, a.email = public.current_user_email()
    from public.admins a
    left join lateral (
      select x.id, x.email_confirmed_at, x.last_sign_in_at
      from auth.users x
      where lower(x.email) = a.email
      order by x.email_confirmed_at desc nulls last
      limit 1
    ) u on true
    order by a.created_at, a.email;
end;
$$;

create or replace function public.admin_add_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.is_admin() then
    raise exception 'Only admins can add admins.' using errcode = '42501';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 254 then
    raise exception 'That doesn''t look like an email address.' using errcode = 'P0001';
  end if;
  insert into public.admins (email) values (v_email) on conflict (email) do nothing;
  -- Touch the account, if there is one, so the trigger sets the flag.
  update auth.users u
  set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
  where lower(u.email) = v_email;
end;
$$;

create or replace function public.admin_remove_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.is_admin() then
    raise exception 'Only admins can remove admins.' using errcode = '42501';
  end if;
  if v_email = public.current_user_email() then
    raise exception 'You can''t remove yourself. Ask another admin to.' using errcode = 'P0001';
  end if;
  -- One at a time, so two admins can't remove each other at once.
  perform pg_advisory_xact_lock(hashtext('public.admins'));
  if (select count(*) from public.admins) <= 1 then
    raise exception 'There has to be at least one admin.' using errcode = 'P0001';
  end if;
  delete from public.admins where email = v_email;
  update auth.users u
  set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
  where lower(u.email) = v_email;
end;
$$;

revoke execute on function public.sync_content_admin() from public, anon, authenticated;
revoke execute on function public.admin_list_admins() from public, anon;
revoke execute on function public.admin_add_admin(text) from public, anon;
revoke execute on function public.admin_remove_admin(text) from public, anon;
grant execute on function public.admin_list_admins() to authenticated;
grant execute on function public.admin_add_admin(text) to authenticated;
grant execute on function public.admin_remove_admin(text) to authenticated;
