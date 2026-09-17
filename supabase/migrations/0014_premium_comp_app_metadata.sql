-- Premium comps move to app metadata.
--
-- The app's hand-granted premium flag, premium_comp, lived in
-- raw_user_meta_data, which any signed-in user can write through the
-- public auth API (the same call the app uses for onboarding answers). So
-- anyone could grant themselves premium. The app now reads the flag from
-- app_metadata, which only the service role can write.
--
-- This moves the grants that exist across, and clears the key from user
-- metadata for everyone, so a value someone planted there does nothing and
-- can't be mistaken for a grant later. Safe to re-run.
-- Run in Supabase dashboard → SQL Editor.

update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                           || '{"premium_comp": true}'::jsonb
 where raw_user_meta_data ->> 'premium_comp' = 'true';

update auth.users
   set raw_user_meta_data = raw_user_meta_data - 'premium_comp'
 where raw_user_meta_data ? 'premium_comp';
