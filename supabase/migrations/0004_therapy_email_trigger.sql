-- Emails the care team automatically whenever a therapy request is
-- created, so users never have to send anything themselves.
-- Uses Brevo (brevo.com) — free tier is 300 emails/day, and no domain
-- DNS setup is needed, just a confirmed sender address.
-- Run in Supabase dashboard → SQL Editor (safe to re-run).
--
-- One-time setup before this does anything:
--   1. Sign up free at brevo.com with reaganprezzo@gmail.com.
--   2. In Brevo: Settings → Senders → make sure reaganprezzo@gmail.com
--      is listed and verified (the signup address usually is).
--   3. In Brevo: Settings → SMTP & API → API Keys → generate a key,
--      then store it in Vault by running:
--        select vault.create_secret('<YOUR_BREVO_API_KEY>', 'brevo_api_key');
--      (To replace it later: select vault.update_secret(id, '<NEW_KEY>')
--       with the id from: select id from vault.secrets where name = 'brevo_api_key';)
--
-- Until the secret exists the trigger quietly does nothing, so this
-- migration is safe to run right away.

create extension if not exists pg_net;

create or replace function public.notify_therapy_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  api_key text;
  user_email text;
  user_name text;
  message text;
begin
  select decrypted_secret into api_key
    from vault.decrypted_secrets
    where name = 'brevo_api_key';
  if api_key is null then
    return new;
  end if;

  select u.email, nullif(trim(u.raw_user_meta_data ->> 'full_name'), '')
    into user_email, user_name
    from auth.users u
    where u.id = new.user_id;

  message := 'New therapy session request'
    || E'\n\n'
    || 'Name: ' || coalesce(user_name, '—') || E'\n'
    || 'Email: ' || coalesce(user_email, '—') || E'\n'
    || 'Would like help with: ' || new.topic || E'\n'
    || 'Availability: '
    || coalesce(nullif(array_to_string(new.availability, ', '), ''), 'Flexible')
    || E'\n'
    || 'Free first session: '
    || case when new.is_free_session then 'Yes' else 'No' end
    || coalesce(E'\n' || 'Note: ' || new.note, '')
    || E'\n\n'
    || 'Reply to this email to reach them directly. Confirm the session '
    || 'with supabase/therapy_ops.sql query 2 (request id ' || new.id || ').';

  perform net.http_post(
    url := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object(
      'api-key', api_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'sender', jsonb_build_object(
        'name', 'Den eisai monos',
        'email', 'reaganprezzo@gmail.com'
      ),
      'to', jsonb_build_array(
        jsonb_build_object('email', 'reagan.owiti@echopsychology.com')
      ),
      'cc', jsonb_build_array(
        jsonb_build_object('email', 'reaganprezzo@gmail.com')
      ),
      'replyTo', jsonb_build_object(
        'email', coalesce(user_email, 'reagan.owiti@echopsychology.com')
      ),
      'subject', 'Therapy request — '
        || coalesce(user_name, user_email, 'new user'),
      'textContent', message
    )
  );
  return new;
end;
$$;

drop trigger if exists therapy_request_notify on public.therapy_requests;
create trigger therapy_request_notify
  after insert on public.therapy_requests
  for each row execute function public.notify_therapy_request();
