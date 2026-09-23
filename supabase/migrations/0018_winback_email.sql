-- One honest email when Premium ends.
--
-- The revenuecat-webhook Edge Function hears when a subscriber turns
-- renewal off (CANCELLATION with cancel_reason UNSUBSCRIBE) or when a
-- subscription or trial runs out (EXPIRATION). It calls send_winback_email
-- with the RevenueCat event id, and this sends one email for that event —
-- never twice, however many times RevenueCat retries the webhook — asking
-- what would have made it worth keeping, and saying that everything they
-- saved is still there and Premium is one tap away in Settings when they
-- want it back.
--
-- It replies to the care team, so an answer reaches a person. No discount
-- is quoted here: win-back offers are set up in Play Console and show up
-- in the app's paywall on their own, so the email stays true whether or
-- not one is configured.
--
-- Run in Supabase dashboard → SQL Editor, after 0017. Then redeploy the
-- webhook:  supabase functions deploy revenuecat-webhook --no-verify-jwt

create table if not exists public.winback_emails (
  event_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('cancelled', 'expired')),
  sent_at timestamptz not null default now()
);
alter table public.winback_emails enable row level security;
-- No policies: written by send_winback_email() only.

create or replace function public.send_winback_email(
  p_user_id uuid,
  p_kind text,
  p_event_id text,
  p_ends_at timestamptz default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  care_team constant text := 'reagan.e.owiti@gmail.com';
  strong constant text := '<strong style="font-weight:600;color:#191919;">';
  client_email text;
  first_name text;
  ends_text text;
  subject text;
  headline text;
  intro text;
  html text;
  plain text;
begin
  if p_kind not in ('cancelled', 'expired') then
    raise exception 'Unknown win-back kind %', p_kind using errcode = '22023';
  end if;
  if nullif(trim(p_event_id), '') is null then
    return false;
  end if;

  -- One email per RevenueCat event. A retry finds the row and stops.
  insert into public.winback_emails (event_id, user_id, kind)
  values (p_event_id, p_user_id, p_kind)
  on conflict (event_id) do nothing;
  if not found then
    return false;
  end if;

  select u.email::text into client_email from auth.users u where u.id = p_user_id;
  if client_email is null then
    return false;
  end if;
  first_name := coalesce(public.therapy_client_first_name(p_user_id), 'there');
  ends_text := case
    when p_ends_at is null then 'the end of your current period'
    else public.email_session_time(p_ends_at)
  end;

  if p_kind = 'cancelled' then
    subject := 'Your Premium stays on until ' || ends_text;
    headline := 'Premium stays on until ' || ends_text;
    intro := 'Hi ' || public.email_escape(first_name) || ', you’ve turned '
      || 'renewal off, so Premium stays on until ' || strong
      || public.email_escape(ends_text) || '</strong> and then stops. '
      || 'Nothing more will be charged.';
    plain := 'Hi ' || first_name || ','
      || E'\n\n'
      || 'You’ve turned renewal off, so Premium stays on until ' || ends_text
      || ' and then stops. Nothing more will be charged.';
  else
    subject := 'Your Premium has ended — everything is still here';
    headline := 'Everything you saved is still here';
    intro := 'Hi ' || public.email_escape(first_name) || ', your Premium has '
      || 'ended. Your journal, your check-ins and your progress are all '
      || 'exactly where you left them.';
    plain := 'Hi ' || first_name || ','
      || E'\n\n'
      || 'Your Premium has ended. Your journal, your check-ins and your '
      || 'progress are all exactly where you left them.';
  end if;

  html := public.email_layout(
    public.email_escape(subject),
    headline,
    intro,
    public.email_box('#F3F6FC', 'Two things',
      '<div style="font-size:12.5px;line-height:1.55;color:#6E6E73;">'
      || '1. If something wasn’t right, ' || strong || 'reply to this email'
      || '</strong> and tell us what would have made it worth keeping. It '
      || 'goes to a person, and it changes what we build.<br><br>'
      || '2. Whenever you want it back, it’s one tap from ' || strong
      || 'Settings → Upgrade</strong> in the app.</div>'),
    'Sent because a subscription on this account changed. No further '
      || 'emails about it will follow.'
  );
  plain := plain
    || E'\n\n'
    || '1. If something wasn’t right, reply to this email and tell us what '
    || 'would have made it worth keeping. It goes to a person.'
    || E'\n'
    || '2. Whenever you want it back, it’s one tap from Settings → Upgrade '
    || 'in the app.'
    || E'\n\n' || '— Δεν είσαι μόνος';

  perform public.send_app_email(
    client_email,
    care_team,
    subject,
    html,
    plain,
    'winback/' || p_event_id
  );
  return true;
end;
$$;

revoke all on function public.send_winback_email(uuid, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.send_winback_email(uuid, text, text, timestamptz) to service_role;
