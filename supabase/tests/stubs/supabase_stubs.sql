-- Just enough of a Supabase project for the migrations to load in a plain
-- Postgres, and for tests to act as an app user. Not a copy of Supabase:
-- only what supabase/migrations uses. Loaded by supabase/tests/run.sh
-- before 0001. Never run this against a real project.

-- ── Roles ────────────────────────────────────────────────────────────
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    create role supabase_admin nologin;
  end if;
end;
$$;
grant anon, authenticated, service_role to authenticator;
-- So tests (connected as postgres) can `set role` to any of them.
grant anon, authenticated, service_role to postgres;

-- ── Schemas and grants, as on a Supabase project ─────────────────────
create schema if not exists extensions;
create schema if not exists auth;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

grant usage on schema public, extensions, auth to anon, authenticated, service_role;

alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- ── auth ─────────────────────────────────────────────────────────────
create table if not exists auth.users (
  instance_id uuid,
  id uuid primary key default gen_random_uuid(),
  aud text default 'authenticated',
  role text default 'authenticated',
  email text,
  phone text,
  encrypted_password text,
  email_confirmed_at timestamptz,
  last_sign_in_at timestamptz,
  raw_app_meta_data jsonb default '{}'::jsonb,
  raw_user_meta_data jsonb default '{}'::jsonb,
  is_anonymous boolean not null default false,
  is_sso_user boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
grant select on auth.users to service_role;

create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
$$;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                         auth.jwt() ->> 'sub'), '')::uuid;
$$;
create or replace function auth.role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), auth.jwt() ->> 'role');
$$;
create or replace function auth.email() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), auth.jwt() ->> 'email');
$$;
grant execute on all functions in schema auth to anon, authenticated, service_role;

-- ── storage ──────────────────────────────────────────────────────────
create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text not null unique,
  owner uuid,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid,
  owner_id text,
  metadata jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_accessed_at timestamptz default now()
);
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1];
$$;
create or replace function storage.filename(name text) returns text language sql immutable as $$
  select (string_to_array(name, '/'))[array_length(string_to_array(name, '/'), 1)];
$$;
create or replace function storage.extension(name text) returns text language sql immutable as $$
  select reverse(split_part(reverse(name), '.', 1));
$$;
grant usage on schema storage to anon, authenticated, service_role;
grant all on storage.objects, storage.buckets to anon, authenticated, service_role;

-- ── vault ────────────────────────────────────────────────────────────
create schema if not exists vault;
create table if not exists vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text unique,
  description text,
  secret text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create or replace view vault.decrypted_secrets as
  select id, name, description, secret, secret as decrypted_secret, created_at, updated_at
  from vault.secrets;
create or replace function vault.create_secret(new_secret text, new_name text default null,
                                               new_description text default '')
returns uuid language sql as $$
  insert into vault.secrets (name, secret, description) values (new_name, new_secret, new_description)
  returning id;
$$;
create or replace function vault.update_secret(secret_id uuid, new_secret text default null,
                                               new_name text default null, new_description text default null)
returns void language sql as $$
  update vault.secrets set secret = coalesce(new_secret, secret), name = coalesce(new_name, name),
         description = coalesce(new_description, description), updated_at = now()
  where id = secret_id;
$$;
