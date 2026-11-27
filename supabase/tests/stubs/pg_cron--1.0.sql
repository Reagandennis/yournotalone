-- Test stand-in for pg_cron: jobs are recorded in cron.job, never run.
create schema if not exists cron;
create table cron.job (
  jobid bigserial primary key,
  schedule text not null,
  command text not null,
  nodename text default 'localhost',
  nodeport integer default 5432,
  database text default current_database(),
  username text default current_user,
  active boolean default true,
  jobname text unique
);
create function cron.schedule(job_name text, schedule text, command text)
returns bigint language sql as $$
  insert into cron.job (jobname, schedule, command) values (job_name, schedule, command)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command
  returning jobid;
$$;
create function cron.schedule(schedule text, command text)
returns bigint language sql as $$
  insert into cron.job (schedule, command) values (schedule, command) returning jobid;
$$;
create function cron.unschedule(job_name text)
returns boolean language plpgsql as $$
begin
  delete from cron.job where jobname = job_name;
  if not found then raise exception 'could not find valid entry for job ''%''', job_name; end if;
  return true;
end;
$$;
create function cron.unschedule(job_id bigint)
returns boolean language plpgsql as $$
begin
  delete from cron.job where jobid = job_id;
  if not found then raise exception 'could not find valid entry for job %', job_id; end if;
  return true;
end;
$$;
