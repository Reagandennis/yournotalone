-- 0026: What people are doing, in aggregate, for recommendations.
--
-- The Worker's daily cron (edge/src/recommend/popularity.ts) calls
-- content_popularity() with the service-role key and publishes the result
-- as stats/popularity.json, a small "popular this month" prior for
-- suggestions. It returns only counts per item: how many different people
-- finished it in the last `days` days. Anything done by fewer than 10
-- people is left out, so a row can never point at one person's habits.
-- Nobody but the service role can call it.
--
-- Also widens practice_sessions.kind so finished reads, journal prompts
-- and tools can be logged too (design §11).
--
-- Paste-run this in the Supabase dashboard → SQL Editor. Safe to re-run.

alter table public.practice_sessions
  drop constraint if exists practice_sessions_kind_check;
alter table public.practice_sessions
  add constraint practice_sessions_kind_check
  check (kind in ('meditation', 'breathing', 'sound', 'lesson', 'prompt', 'tool'));

create or replace function public.content_popularity(days int default 30)
returns table (kind text, slug text, users bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select ps.kind, ps.slug, count(distinct ps.user_id) as users
  from public.practice_sessions ps
  where ps.completed_at >= now() - make_interval(days => least(greatest(coalesce(content_popularity.days, 30), 1), 365))
  group by ps.kind, ps.slug
  having count(distinct ps.user_id) >= 10
  order by users desc, ps.kind, ps.slug;
$$;

-- Functions are executable by everyone by default; this one isn't.
revoke all on function public.content_popularity(int) from public, anon, authenticated;
grant execute on function public.content_popularity(int) to service_role;
