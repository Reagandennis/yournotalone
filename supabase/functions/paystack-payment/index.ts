// Takes payment for a therapy session through Paystack.
//
// The app sends { request_id, action }:
//   action "start"    opens a Paystack checkout for the session and returns
//                     { authorization_url, reference } for the app to show,
//                     or { paid: true } if it's already paid for.
//   no action         confirms: asks Paystack about this session's
//                     checkouts and marks the session paid if one succeeded.
//                     { paid: true }, or 402 no_payment_found.
//
// The app's word is never taken: only Paystack's record of a transaction,
// for the amount the checkout was opened with, marks a session paid. Each
// transaction pays for exactly one session — its reference goes into
// therapy_requests.payment_ref as 'paystack:<reference>', which is unique.
// paystack-webhook does the same on charge.success, so a payment lands even
// if the app closed before confirming.
//
// Deploy:  supabase functions deploy paystack-payment
// Secrets: PAYSTACK_SECRET_KEY    Paystack → Settings → API Keys & Webhooks
//                                 (sk_test_… while testing, sk_live_… after)
//          PAYSTACK_CALLBACK_URL  optional; where Paystack sends the browser
//                                 after paying, e.g. a "return to the app" page
// Prices are shown in USD (the session's price_cents), but the Paystack
// account settles in Kenyan shillings, so every checkout charges
// CHARGE_AMOUNT in CHARGE_CURRENCY instead. Optional secrets
// PAYSTACK_CHARGE_AMOUNT (in cents, e.g. 260000) and PAYSTACK_CHARGE_CURRENCY
// override them without a redeploy; change therapySessionChargeLabel in
// lib/therapy/therapy_repository.dart to match.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  type Checkout,
  paystack,
  PAYSTACK_SECRET_KEY,
  settleCheckout,
  verifyTransaction,
} from '../_shared/paystack.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CALLBACK_URL = Deno.env.get('PAYSTACK_CALLBACK_URL');
// Ksh 2,600, in cents.
const CHARGE_AMOUNT = Number(Deno.env.get('PAYSTACK_CHARGE_AMOUNT') ?? 260000);
const CHARGE_CURRENCY = (Deno.env.get('PAYSTACK_CHARGE_CURRENCY') ?? 'KES').toUpperCase();

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'missing_token' }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: 'invalid_token' }, 401);

  let requestId = '';
  let action = 'confirm';
  try {
    const body = await req.json();
    requestId = typeof body?.request_id === 'string' ? body.request_id : '';
    if (body?.action === 'start') action = 'start';
  } catch {
    // Falls through to the check below.
  }
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return json({ error: 'bad_request' }, 400);

  const { data: session, error: sessionError } = await admin
    .from('therapy_requests')
    .select('id, user_id, status, payment_status, price_cents, currency')
    .eq('id', requestId)
    .maybeSingle();
  if (sessionError) {
    console.error('paystack-payment: lookup failed', requestId, sessionError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (!session || session.user_id !== user.id) return json({ error: 'not_found' }, 404);
  if (session.payment_status !== 'unpaid') return json({ paid: true });
  // A draft (awaiting_payment) is what the app pays for first; the database
  // moves it to pending the moment the payment lands (migration 0019).
  if (!['awaiting_payment', 'pending', 'confirmed'].includes(session.status)) {
    return json({ error: 'not_payable' }, 409);
  }

  if (!PAYSTACK_SECRET_KEY) {
    console.error('paystack-payment: PAYSTACK_SECRET_KEY is not set');
    return json({ error: 'not_configured' }, 503);
  }

  // Either way, look at the checkouts already opened for this session
  // first: one may have been paid while the app wasn't looking.
  const { data: checkouts, error: checkoutsError } = await admin
    .from('paystack_checkouts')
    .select('reference, request_id, user_id, amount, currency')
    .eq('request_id', session.id)
    .eq('user_id', user.id)
    .is('refund_requested_at', null)
    .order('created_at', { ascending: false })
    .limit(5);
  if (checkoutsError) {
    console.error('paystack-payment: checkouts lookup failed', checkoutsError);
    return json({ error: 'lookup_failed' }, 500);
  }

  try {
    for (const checkout of (checkouts ?? []) as Checkout[]) {
      const transaction = await verifyTransaction(checkout.reference);
      if (!transaction) continue;
      const result = await settleCheckout(admin, checkout, transaction);
      if (result === 'paid') return json({ paid: true });
    }
  } catch (error) {
    console.error('paystack-payment: verification failed', error);
    return json({ error: 'verification_failed' }, 502);
  }

  if (action !== 'start') return json({ error: 'no_payment_found' }, 402);

  if (!user.email) return json({ error: 'email_required' }, 400);
  if (!(Number(session.price_cents) > 0)) return json({ error: 'not_payable' }, 409);
  const amount = CHARGE_AMOUNT;
  const currency = CHARGE_CURRENCY;
  if (!(amount > 0)) {
    console.error('paystack-payment: bad PAYSTACK_CHARGE_AMOUNT');
    return json({ error: 'not_configured' }, 503);
  }

  const reference = `therapy-${session.id.slice(0, 8)}-${crypto.randomUUID()}`;
  const { error: insertError } = await admin.from('paystack_checkouts').insert({
    reference,
    request_id: session.id,
    user_id: user.id,
    amount,
    currency,
  });
  if (insertError) {
    console.error('paystack-payment: checkout insert failed', insertError);
    return json({ error: 'update_failed' }, 500);
  }

  try {
    const data = await paystack('/transaction/initialize', {
      method: 'POST',
      body: JSON.stringify({
        email: user.email,
        amount,
        currency,
        reference,
        ...(CALLBACK_URL ? { callback_url: CALLBACK_URL } : {}),
        metadata: {
          request_id: session.id,
          user_id: user.id,
          custom_fields: [
            { display_name: 'Item', variable_name: 'item', value: 'Therapy session' },
            {
              display_name: 'Price',
              variable_name: 'price_usd',
              value: `US$${(Number(session.price_cents) / 100).toFixed(2)}`,
            },
          ],
        },
      }),
    });
    return json({ authorization_url: data.authorization_url, reference });
  } catch (error) {
    console.error('paystack-payment: initialize failed', error);
    return json({ error: 'checkout_failed' }, 502);
  }
});
