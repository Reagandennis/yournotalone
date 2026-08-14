-- 0005: Public "avatars" storage bucket for profile pictures.
-- Files live at <user-id>/avatar.jpg; the public URL is stored in
-- auth user metadata as avatar_url.
--
-- Paste-run this in the Supabase dashboard SQL Editor.
-- (RLS is already enabled on storage.objects by default — no ALTER TABLE needed.)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Anyone may view avatars (the bucket is public anyway; this covers API reads).
create policy "Avatars are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Users may only write inside their own <user-id>/ folder.
create policy "Users upload their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users update their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
