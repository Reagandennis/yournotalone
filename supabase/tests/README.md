# Migration tests

Loads every migration in `supabase/migrations` (0001 → newest, then the
newest again to prove it re-runs) into a throwaway Postgres in Docker and
runs the `*_test.sql` behaviour tests here. Never touches the live project.

```sh
supabase/tests/run.sh                       # local Docker, all tests
supabase/tests/run.sh 0040_organizations    # one test
supabase/tests/run_remote.sh                # on the ops server's Docker over SSH
KEEP=1 supabase/tests/run.sh                # leave the container up to poke at
```

`stubs/` stands in for the Supabase parts a plain Postgres lacks: the
`auth` schema (`auth.users`, `auth.uid()`, `auth.jwt()`, `auth.role()`),
the `anon` / `authenticated` / `service_role` roles with Supabase's default
grants, `storage`, `vault`, and fake `pg_cron` / `pg_net` extensions (jobs
recorded in `cron.job`, requests — so emails — in `net.http_request_queue`).

A test acts as someone with `select tests.login('a@b.com'); set role
authenticated;` and records each assertion with `tests.check(…)` /
`tests.throws(…)`; it fails at the end if any check failed.
