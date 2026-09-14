-- Therapy request emails, sent with Resend (resend.com).
--
-- Replaces the Brevo notification from 0004. Every new request now sends
-- two emails:
--   1. The care team (reagan.e.owiti@gmail.com) gets the user's name,
--      email and everything they filled in. Reply-To is the user, so
--      hitting Reply reaches them directly.
--   2. The user gets a confirmation, styled like the app: we've received
--      their request and will connect them with a therapist within 24
--      hours. Reply-To is the care team.
--
-- Run in Supabase dashboard → SQL Editor (safe to re-run).
--
-- One-time setup:
--   1. Store the Resend API key in Vault:
--        select vault.create_secret('<YOUR_RESEND_API_KEY>', 'resend_api_key');
--      (To replace it later: select vault.update_secret(id, '<NEW_KEY>')
--       with the id from: select id from vault.secrets where name = 'resend_api_key';)
--   2. Verify a sending domain in Resend (Domains → Add domain, then add
--      the DNS records it shows) and store the sender address:
--        select vault.create_secret('Den eisai monos <care@your-domain.com>', 'resend_from');
--      Until then mail goes out from onboarding@resend.dev, which Resend
--      only delivers to the email address that owns the Resend account.
--      So the care-team email works if that is reagan.e.owiti@gmail.com,
--      but confirmations to users are refused (HTTP 403) until a domain
--      is verified.
--
-- Until the API key exists the trigger quietly does nothing. Email
-- problems never block a booking: the request is saved either way.
-- Delivery results land in net._http_response (therapy_ops.sql query 5).

create extension if not exists pg_net;

-- Names and notes are typed by users; escape them before they go into HTML.
create or replace function public.email_escape(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select replace(replace(replace(replace(replace(coalesce(value, ''),
    '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '''', '&#39;');
$$;

-- One label/value line in a details panel. value is HTML, so escape
-- anything user-supplied before passing it in.
create or replace function public.email_row(label text, value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select '<tr><td width="112" valign="top" style="width:112px;padding:6px 12px 6px 0;font-size:13px;line-height:1.5;color:#6E6E73;">'
    || label
    || '</td><td valign="top" style="padding:6px 0;font-size:13px;line-height:1.5;font-weight:500;color:#191919;">'
    || value
    || '</td></tr>';
$$;

-- A rounded, tinted panel with a title, like the app's cards. tint is
-- #F3F6FC (brand blue, as on the booking card) or #F6F6F6 (ink, as on
-- the reassurance panel).
create or replace function public.email_box(tint text, title text, body text)
returns text
language sql
immutable
set search_path = ''
as $$
  select '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:'
    || tint
    || ';border-radius:18px;"><tr><td style="padding:20px 22px;">'
    || '<div style="padding-bottom:6px;font-size:15px;font-weight:600;color:#191919;">'
    || title
    || '</div>'
    || body
    || '</td></tr></table>';
$$;

-- The frame both emails share, drawn from the app: white ground, Poppins,
-- an ink headline with the four-pillar stripe under it, muted body text.
-- Table layout and inline styles, because that's what mail clients render.
create or replace function public.email_layout(
  preheader text,
  headline text,
  intro text,
  content text,
  footer text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select $html$<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  body, table, td, div, a { font-family: Poppins, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
  a { color: #3764CD; text-decoration: none; }
  @media (max-width: 480px) { .frame { padding: 28px 20px !important; } }
</style>
</head>
<body style="margin:0;padding:0;background:#FFFFFF;-webkit-text-size-adjust:100%;">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">$html$
    || preheader
    || $html$</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#FFFFFF;">
<tr><td align="center" class="frame" style="padding:40px 28px;font-family:Poppins,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;">
<tr><td align="center" style="padding-bottom:30px;font-size:14px;font-weight:600;letter-spacing:0.3px;color:#191919;">Δεν είσαι μόνος</td></tr>
<tr><td align="center" style="font-size:24px;line-height:1.25;font-weight:600;color:#191919;">$html$
    || headline
    || $html$</td></tr>
<tr><td align="center" style="padding:14px 0 16px;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
<td width="30" height="5" style="width:30px;height:5px;background:#E12D23;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
<td width="4" style="width:4px;font-size:0;line-height:0;">&nbsp;</td>
<td width="30" height="5" style="width:30px;height:5px;background:#3764CD;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
<td width="4" style="width:4px;font-size:0;line-height:0;">&nbsp;</td>
<td width="30" height="5" style="width:30px;height:5px;background:#191919;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
<td width="4" style="width:4px;font-size:0;line-height:0;">&nbsp;</td>
<td width="30" height="5" style="width:30px;height:5px;background:#FAB414;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
</tr></table>
</td></tr>
<tr><td align="center" style="padding-bottom:28px;font-size:14px;line-height:1.6;color:#6E6E73;">$html$
    || intro
    || $html$</td></tr>
<tr><td>$html$
    || content
    || $html$</td></tr>
<tr><td style="padding-top:28px;"><div style="border-top:1px solid #E5E5EA;font-size:0;line-height:0;">&nbsp;</div></td></tr>
<tr><td align="center" style="padding-top:18px;font-size:12px;line-height:1.6;color:#6E6E73;">$html$
    || footer
    || $html$</td></tr>
</table>
</td></tr>
</table>
</body>
</html>$html$;
$$;

-- Only the trigger below needs these; keep them off the public API.
revoke execute on function public.email_escape(text) from public, anon, authenticated;
revoke execute on function public.email_row(text, text) from public, anon, authenticated;
revoke execute on function public.email_box(text, text, text) from public, anon, authenticated;
revoke execute on function public.email_layout(text, text, text, text, text) from public, anon, authenticated;

create or replace function public.notify_therapy_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  api_key text;
  sender text;
  user_email text;
  user_name text;
  first_name text;
  display_name text;
  availability text;
  requested_at text;
  reply_by text;
  team_html text;
  team_text text;
  user_html text;
  user_text text;
begin
  select decrypted_secret into api_key
    from vault.decrypted_secrets
    where name = 'resend_api_key';
  if api_key is null then
    return new;
  end if;

  select decrypted_secret into sender
    from vault.decrypted_secrets
    where name = 'resend_from';
  sender := coalesce(
    nullif(trim(sender), ''),
    'Den eisai monos <onboarding@resend.dev>'
  );

  -- Whitespace collapsed so a stray newline in a name can't break the
  -- subject line.
  select u.email,
         nullif(trim(regexp_replace(
           coalesce(u.raw_user_meta_data ->> 'full_name',
                    u.raw_user_meta_data ->> 'name', ''),
           '\s+', ' ', 'g')), '')
    into user_email, user_name
    from auth.users u
    where u.id = new.user_id;
  first_name := split_part(user_name, ' ', 1);
  display_name := coalesce(user_name, user_email, 'Someone');

  availability := coalesce(
    nullif(array_to_string(new.availability, ' · '), ''),
    'Flexible'
  );
  -- The care team works in Nairobi time (see therapy_ops.sql query 2).
  requested_at := to_char(new.created_at at time zone 'Africa/Nairobi',
    'Dy FMDD Mon YYYY, HH24:MI') || ' Nairobi time';
  reply_by := to_char(
    (new.created_at + interval '24 hours') at time zone 'Africa/Nairobi',
    'Dy FMDD Mon, HH24:MI') || ' Nairobi time';

  -- ── 1. To the care team ────────────────────────────────────────
  team_html := public.email_layout(
    public.email_escape(display_name) || ' · ' || public.email_escape(new.topic),
    'New therapy request',
    '<strong style="font-weight:600;color:#191919;">'
      || public.email_escape(display_name)
      || '</strong> would like to talk to a therapist. They’ve been told '
      || 'we’ll connect them within 24 hours — by '
      || '<strong style="font-weight:600;color:#191919;">'
      || reply_by || '</strong>.',
    public.email_box('#F3F6FC', 'Request details',
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
      || public.email_row('Name', public.email_escape(coalesce(user_name, '—')))
      || public.email_row('Email', case when user_email is null then '—'
           else '<a href="mailto:' || public.email_escape(user_email)
             || '" style="color:#3764CD;text-decoration:none;">'
             || public.email_escape(user_email) || '</a>' end)
      || public.email_row('Focus', public.email_escape(new.topic))
      || public.email_row('Availability', public.email_escape(availability))
      || public.email_row('Free session',
           case when new.is_free_session then 'Yes — their first'
             else 'No — $' || (new.price_cents / 100) || ', paid in the app once matched' end)
      || case when nullif(trim(new.note), '') is null then ''
           else public.email_row('Note',
             replace(public.email_escape(new.note), E'\n', '<br>')) end
      || public.email_row('Requested', requested_at)
      || public.email_row('Request ID',
           '<span style="font-family:Menlo,Consolas,monospace;font-size:12px;color:#6E6E73;">'
           || new.id || '</span>')
      || '</table>')
    || '<div style="height:12px;font-size:0;line-height:0;">&nbsp;</div>'
    || public.email_box('#F6F6F6', 'Next step',
      '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
      || 'Open <strong style="font-weight:600;color:#191919;">Settings → Care team</strong> '
      || 'in the app to match them with a therapist and a time. They’re emailed '
      || 'the details and join the video call from the app. Reply to this email '
      || 'to reach them directly.</div>'),
    'Sent automatically when someone asks for a therapist in the Δεν είσαι μόνος app.'
  );

  team_text := 'New therapy request'
    || E'\n\n'
    || 'Name: ' || coalesce(user_name, '—') || E'\n'
    || 'Email: ' || coalesce(user_email, '—') || E'\n'
    || 'Would like help with: ' || new.topic || E'\n'
    || 'Availability: ' || availability || E'\n'
    || 'Free first session: '
    || case when new.is_free_session then 'Yes'
         else 'No ($' || (new.price_cents / 100) || ')' end
    || coalesce(E'\n' || 'Note: ' || nullif(trim(new.note), ''), '')
    || E'\n' || 'Requested: ' || requested_at
    || E'\n\n'
    || 'They’ve been told we’ll connect them within 24 hours — by '
    || reply_by || '.'
    || E'\n\n'
    || 'Match them with a therapist from Settings → Care team in the app. '
    || 'Reply to this email to reach them directly (request id ' || new.id || ').';

  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || api_key,
      'Content-Type', 'application/json',
      'Idempotency-Key', 'therapy-request/' || new.id || '/care-team'
    ),
    body := jsonb_strip_nulls(jsonb_build_object(
      'from', sender,
      'to', jsonb_build_array(care_team),
      'reply_to', user_email,
      'subject', 'Therapy request — ' || display_name,
      'html', team_html,
      'text', team_text
    )),
    timeout_milliseconds := 10000
  );

  -- ── 2. To the user ─────────────────────────────────────────────
  -- What they asked for, what happens next, and where to turn if 24
  -- hours is too long to wait. Their note stays out of it: it's theirs,
  -- and inboxes get read over shoulders.
  if user_email is not null then
    user_html := public.email_layout(
      'We’ll connect you with a licensed therapist within 24 hours.',
      'We’ve received your request',
      'Hi ' || public.email_escape(coalesce(first_name, 'there'))
        || ', thank you for reaching out — that takes courage. We’ll '
        || 'connect you with a licensed therapist within '
        || '<strong style="font-weight:600;color:#191919;">24 hours</strong>, '
        || 'by email.',
      public.email_box('#F3F6FC', 'Your request',
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        || public.email_row('Focus', public.email_escape(new.topic))
        || public.email_row('Availability', public.email_escape(availability))
        || case when new.is_free_session
             then public.email_row('First session',
               '<span style="color:#E12D23;">&#9829;</span>&nbsp;Free, on us')
             else public.email_row('Price',
               '$' || (new.price_cents / 100) || ' — you pay in the app once you’re matched')
             end
        || '</table>')
      || $html$
<div style="padding:30px 0 14px;font-size:16px;font-weight:600;color:#191919;">What happens next</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">1</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">We match you</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">Our care team finds a licensed therapist for what you shared, usually within 24 hours.</div></td>
</tr>
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">2</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">You see your booking</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">Your therapist and session time appear in the app, and we email them to you. Can’t make it? Just reply.</div></td>
</tr>
<tr>
<td width="44" valign="top" style="width:44px;padding-bottom:16px;"><div style="width:30px;height:30px;border-radius:15px;background:#EBF0FA;color:#3764CD;font-size:13px;font-weight:600;line-height:30px;text-align:center;">3</div></td>
<td valign="top" style="padding-bottom:16px;"><div style="font-size:14.5px;line-height:1.4;font-weight:600;color:#191919;">You talk</div><div style="padding-top:2px;font-size:13px;line-height:1.5;color:#6E6E73;">A private video call, right in the app. What you say stays between you and them.</div></td>
</tr>
</table>
<div style="height:8px;font-size:0;line-height:0;">&nbsp;</div>
$html$
      || public.email_box('#F6F6F6', 'In crisis or immediate danger?',
        '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
        || 'Please don’t wait for us. Call your local emergency number — '
        || '112 in Greece and across the EU, 999 in Kenya and the UK, 911 in '
        || 'the US — or tap <strong style="font-weight:600;color:#191919;">'
        || 'Get help now</strong> in the app for crisis lines near you.</div>'),
      'Questions, or something’s changed? Just reply — this email comes '
        || 'straight to our care team.<br>You’re receiving this because you '
        || 'asked for a therapist in the Δεν είσαι μόνος app.'
    );

    user_text := 'Hi ' || coalesce(first_name, 'there') || ','
      || E'\n\n'
      || 'Thank you for reaching out — that takes courage. We’ve received '
      || 'your request and we’ll connect you with a licensed therapist '
      || 'within 24 hours, by email.'
      || E'\n\n'
      || 'Your request' || E'\n'
      || 'Focus: ' || new.topic || E'\n'
      || 'Availability: ' || availability
      || case when new.is_free_session
           then E'\n' || 'First session: Free, on us'
           else E'\n' || 'Price: $' || (new.price_cents / 100) || ', paid in the app once you’re matched' end
      || E'\n\n'
      || 'What happens next' || E'\n'
      || '1. We match you — our care team finds a licensed therapist for '
      || 'what you shared, usually within 24 hours.' || E'\n'
      || '2. You see your booking — your therapist and session time appear '
      || 'in the app, and we email them to you.' || E'\n'
      || '3. You talk — a private video call, right in the app.'
      || E'\n\n'
      || 'In crisis or immediate danger? Please don’t wait for us. Call '
      || 'your local emergency number (112 in Greece and across the EU, 999 '
      || 'in Kenya and the UK, 911 in the US) or tap Get help now in the app.'
      || E'\n\n'
      || 'Questions, or something’s changed? Just reply to this email.'
      || E'\n\n'
      || '— Δεν είσαι μόνος';

    perform net.http_post(
      url := 'https://api.resend.com/emails',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || api_key,
        'Content-Type', 'application/json',
        'Idempotency-Key', 'therapy-request/' || new.id || '/user'
      ),
      body := jsonb_build_object(
        'from', sender,
        'to', jsonb_build_array(user_email),
        'reply_to', care_team,
        'subject', 'We’ve received your request',
        'html', user_html,
        'text', user_text
      ),
      timeout_milliseconds := 10000
    );
  end if;

  return new;
exception when others then
  -- Never lose a booking over an email: log it and keep the request.
  raise warning 'therapy request % email failed: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists therapy_request_notify on public.therapy_requests;
create trigger therapy_request_notify
  after insert on public.therapy_requests
  for each row execute function public.notify_therapy_request();
