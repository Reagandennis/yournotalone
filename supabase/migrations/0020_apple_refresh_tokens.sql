-- Sign in with Apple: refresh tokens for revoking on account deletion.
--
-- App Store guideline 5.1.1(v): an app that offers Sign in with Apple must,
-- when the user deletes their account, also revoke the app's access with
-- Apple. Revoking takes a token Apple issued to us, and the only one that
-- lasts is the refresh token — which Apple hands out solely in exchange for
-- the five-minute authorization code the app gets at sign-in. So:
--
--   • right after an Apple sign-in, the app sends that code to the
--     apple-token Edge Function, which swaps it for a refresh token and
--     stores it here;
--   • the delete-account Edge Function revokes it with Apple before
--     deleting the auth user, and the row goes with the user.
--
-- The tokens are credentials: RLS is on with no policies and the API roles
-- have no grants, so only the service role (the Edge Functions) can touch
-- them.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run). Then deploy:
--   supabase functions deploy apple-token
--   supabase functions deploy delete-account

create table if not exists public.apple_refresh_tokens (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  refresh_token text not null,
  updated_at    timestamptz not null default now()
);

alter table public.apple_refresh_tokens enable row level security;

revoke all on public.apple_refresh_tokens from anon, authenticated;
