// Takes payment for a therapy session through Paystack.
//
// The app sends { request_id, action }:
//   action "start"    opens a Paystack checkout for the session and returns
//                     { authorization_url, reference } for the app to show,
//                     or { paid: true } if it's already paid for. If the
//                     newest checkout is under PAYMENT_IN_PROGRESS_MS old
//                     and Paystack says the customer is still paying on it
//                     (an M-Pesa prompt on their phone, a charge still
//                     processing — IN_PROGRESS_STATUSES), or Paystack hasn't
//                     heard of it yet, no second transaction is opened —
//                     that is how a client got charged twice — and the
//                     answer is 409 { error: 'payment_in_progress',
//                     reference, opened_at }: the app offers "Check
//                     payment" (a confirm) instead. Every recent checkout
//                     counts, not only the newest, and a start that races
//                     another one gets the other's reference
//                     (paystack_open_checkout, migration 0038). Paystack's verify doesn't give back
//                     the authorization_url, so the old page can't be
//                     reopened.
//   no action         confirms: asks Paystack about this session's
//                     checkouts and marks the session paid if one succeeded.
//                     { paid: true }; with report_in_progress: true, 409
//                     payment_in_progress (as above) while one may still
//                     be paid; else 402 no_payment_found.
//
// A 2xx always carries either paid: true or an https authorization_url; a
// checkout Paystack opened without one is 502 checkout_failed. A checkout
// Paystack refused to open is removed, so it doesn't block the next start.
// Checkouts that were refunded (refunded_at, migration 0036) or sent to the
// care team for a refund are never looked at again, so a refunded
// transaction can't pay for the session a second time.
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
// Prices are shown in the client's currency (the session's price_cents and
// currency), but the Paystack account settles in Kenyan shillings, so each
// checkout charges the session's charge_minor in charge_currency, set from
// the price list for the client's country when they booked (migration
// 0031). Sessions booked before that have no charge on them and get
// CHARGE_AMOUNT in CHARGE_CURRENCY; optional secrets PAYSTACK_CHARGE_AMOUNT
// (in cents, e.g. 260000) and PAYSTACK_CHARGE_CURRENCY override those.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  type Checkout,
  IN_PROGRESS_STATUSES,
  type Item,
  paystack,
  PaystackError,
  PAYSTACK_SECRET_KEY,
  recordCardCountry,
  settleCheckout,
  verifyTransaction,
} from '../_shared/paystack.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CALLBACK_URL = Deno.env.get('PAYSTACK_CALLBACK_URL');
// Ksh 2,600, in cents, for sessions booked before 0031.
const CHARGE_AMOUNT = Number(Deno.env.get('PAYSTACK_CHARGE_AMOUNT') ?? 260000);
const CHARGE_CURRENCY = (Deno.env.get('PAYSTACK_CHARGE_CURRENCY') ?? 'KES').toUpperCase();
// How long a checkout the customer may still be paying on blocks a new one.
// An M-Pesa STK prompt times out well inside this.
const PAYMENT_IN_PROGRESS_MS = 15 * 60 * 1000;

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
  // Apps that know a confirm can answer payment_in_progress say so; older
  // ones get 402 no_payment_found as before.
  let reportInProgress = false;
  try {
    const body = await req.json();
    requestId = typeof body?.request_id === 'string' ? body.request_id : '';
    if (body?.action === 'start') action = 'start';
    reportInProgress = body?.report_in_progress === true;
  } catch {
    // Falls through to the check below.
  }
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return json({ error: 'bad_request' }, 400);

  const { data: session, error: sessionError } = await admin
    .from('therapy_requests')
    .select('id, user_id, status, payment_status, price_cents, currency, charge_minor, charge_currency')
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
    .select('reference, request_id, user_id, amount, currency, created_at, refunded_at')
    .eq('request_id', session.id)
    .eq('user_id', user.id)
    .is('refund_requested_at', null)
    .is('refunded_at', null)
    .order('created_at', { ascending: false })
    .limit(5);
  if (checkoutsError) {
    console.error('paystack-payment: checkouts lookup failed', checkoutsError);
    return json({ error: 'lookup_failed' }, 500);
  }

  // What Paystack said about each checkout (null: it has no record).
  const opened = (checkouts ?? []) as Checkout[];
  const newest = opened[0];
  const transactions = new Map<string, Item | null>();
  try {
    for (const checkout of opened) {
      const transaction = await verifyTransaction(checkout.reference);
      transactions.set(checkout.reference, transaction);
      if (!transaction) continue;
      const result = await settleCheckout(admin, checkout, transaction);
      if (result === 'paid') {
        await recordCardCountry(admin, checkout.reference, transaction);
        return json({ paid: true });
      }
    }
  } catch (error) {
    console.error('paystack-payment: verification failed', error);
    return json({ error: 'verification_failed' }, 502);
  }

  // Don't open a second transaction while the customer may still be paying
  // on any earlier one — they'd be charged twice — and don't tell a confirm
  // there's nothing to find while one may still be paid (the app keeps the
  // draft and "Check payment" for it).
  const live = opened.find((checkout) => {
    const age = Date.now() - Date.parse(checkout.created_at ?? '');
    if (!(Number.isFinite(age) && age < PAYMENT_IN_PROGRESS_MS)) return false;
    const transaction = transactions.get(checkout.reference);
    // No record at Paystack: the newest may still be being opened.
    if (!transaction) return checkout === newest;
    return IN_PROGRESS_STATUSES.includes(String(transaction.status ?? '').toLowerCase());
  });
  if (live && (action === 'start' || reportInProgress)) {
    return inProgress(live.reference, live.created_at);
  }

  if (action !== 'start') return json({ error: 'no_payment_found' }, 402);

  if (!user.email) return json({ error: 'email_required' }, 400);
  if (!(Number(session.price_cents) > 0)) return json({ error: 'not_payable' }, 409);
  const amount = Number(session.charge_minor) > 0 ? Number(session.charge_minor) : CHARGE_AMOUNT;
  const currency = session.charge_minor ? String(session.charge_currency ?? 'KES').toUpperCase() : CHARGE_CURRENCY;
  if (!(amount > 0)) {
    console.error('paystack-payment: bad PAYSTACK_CHARGE_AMOUNT');
    return json({ error: 'not_configured' }, 503);
  }

  // Recorded only if no other start recorded one since this one looked
  // (migration 0038), so two starts at once can't open two checkouts.
  const reference = `therapy-${session.id.slice(0, 8)}-${crypto.randomUUID()}`;
  const { data: other, error: insertError } = await admin.rpc('paystack_open_checkout', {
    p_reference: reference,
    p_request_id: session.id,
    p_user_id: user.id,
    p_amount: amount,
    p_currency: currency,
    p_seen: opened.map((c) => c.reference),
  });
  if (insertError) {
    console.error('paystack-payment: checkout insert failed', insertError);
    return json({ error: 'update_failed' }, 500);
  }
  if (typeof other === 'string' && other !== '') return inProgress(other, new Date().toISOString());

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
              variable_name: 'price',
              value: `${String(session.currency ?? 'USD').toUpperCase()} ${(Number(session.price_cents) / 100).toFixed(2)}`,
            },
          ],
        },
      }),
    });
    const page = checkoutPage(data.authorization_url);
    if (!page) {
      // Paystack may have opened the transaction, so the row stays: a later
      // charge.success needs it to find the session.
      console.error('paystack-payment: initialize gave no authorization_url', reference, data);
      return json({ error: 'checkout_failed' }, 502);
    }
    return json({ authorization_url: page, reference });
  } catch (error) {
    console.error('paystack-payment: initialize failed', error);
    // Paystack answered and refused (4xx, or status false): no transaction
    // exists, so the row goes and doesn't hold up the next start as "in
    // progress". A network failure or a 5xx may have opened one: it stays.
    if (error instanceof PaystackError && error.status < 500) {
      const { error: deleteError } = await admin.from('paystack_checkouts')
        .delete()
        .eq('reference', reference);
      if (deleteError) console.error('paystack-payment: checkout not removed', reference, deleteError);
    }
    return json({ error: 'checkout_failed' }, 502);
  }
});

/// 409: a checkout opened at [openedAt] may still be paid. The app waits
/// for it from then, offering "Check payment" instead of "Pay".
function inProgress(reference: string, openedAt: string | undefined): Response {
  return json({
    error: 'payment_in_progress',
    reference,
    ...(openedAt ? { opened_at: openedAt } : {}),
  }, 409);
}

/// The checkout page Paystack gave, if it's a usable https URL.
function checkoutPage(raw: unknown): string | null {
  if (typeof raw !== 'string' || raw.trim() === '') return null;
  try {
    const url = new URL(raw.trim());
    return url.protocol === 'https:' && url.hostname !== '' ? url.toString() : null;
  } catch {
    return null;
  }
}
