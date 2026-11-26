// The unsubscribe link in the win-back emails (send_engagement_emails() in
// migration 0036): turns those emails off for the account the token belongs
// to, without signing in. The token can do nothing else.
//
// Two ways in, both with the token as ?t=<uuid>:
//   GET   someone tapped "Stop these emails" in the email.
//   POST  a mail client's one-click "Unsubscribe" (RFC 8058), which sends
//         List-Unsubscribe=One-Click in the body.
//
// The answer is the same whether or not the token was real, so the link
// can't be used to test tokens. It's plain text: Supabase serves Edge
// Function HTML as text anyway.
//
// Deploy:  supabase functions deploy email-preferences --no-verify-jwt
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const DONE =
  'You won’t get any more emails from Δεν είσαι μόνος about being away.\n\n' +
  'Changed your mind? Turn them back on in the app under Settings → Reminders.\n';

function text(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return text('Method not allowed\n', 405);
  }
  const token = new URL(req.url).searchParams.get('t') ?? '';
  if (!UUID.test(token)) return text(DONE);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await admin.rpc('email_unsubscribe', { p_token: token });
  if (error) {
    // Logged without the token: it's a credential, if a weak one.
    console.error('email_unsubscribe failed:', error.message);
    return text('Something went wrong. Please try the link again in a minute.\n', 500);
  }
  return text(DONE);
});
