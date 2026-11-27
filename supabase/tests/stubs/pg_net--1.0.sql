-- Test stand-in for pg_net: every request is recorded in
-- net.http_request_queue (tests read emails from it); nothing is sent.
create schema if not exists net;
create table net.http_request_queue (
  id bigserial primary key,
  method text not null,
  url text not null,
  headers jsonb,
  body jsonb,
  timeout_milliseconds integer,
  created_at timestamptz not null default clock_timestamp()
);
create table net._http_response (
  id bigint,
  status_code integer,
  content_type text,
  headers jsonb,
  content text,
  timed_out boolean,
  error_msg text,
  created timestamptz not null default now()
);
create function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type": "application/json"}'::jsonb,
  timeout_milliseconds integer default 5000)
returns bigint language sql security definer as $$
  insert into net.http_request_queue (method, url, headers, body, timeout_milliseconds)
  values ('POST', url, headers, body, timeout_milliseconds) returning id;
$$;
create function net.http_get(
  url text,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 5000)
returns bigint language sql security definer as $$
  insert into net.http_request_queue (method, url, headers, timeout_milliseconds)
  values ('GET', url, headers, timeout_milliseconds) returning id;
$$;
