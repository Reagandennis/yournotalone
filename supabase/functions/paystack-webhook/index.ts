// Hears from Paystack about therapy session payments.
//
//   charge.success     marks the session paid, the same way paystack-payment
//                      does, so a payment lands even if the app closed
//                      before confirming it.
//                      The card's country is kept with the checkout
//                      (paystack_record_card_country, 0036).
//   refund.processed   a full refund (data.amount, in the currency's minor
//                      unit, at least the checkout's amount — or partial
//                      refunds Paystack lists as processed that add up to
//                      it; a refund with no amount is taken as full) marks
//                      the checkout refunded_at and puts the session back
//                      to unpaid through record_therapy_refunds (migration
//                      0012, worded for Paystack in 0021; 0036 sets
//                      refunded_at too), which emails the care team and the
//                      client. A refund short of the full amount is only
//                      logged: the session stays paid. Either way the
//                      checkout is never attached to a session again once
//                      it's marked refunded (see ../_shared/paystack.ts).
//
// Every event is checked against the x-paystack-signature header (HMAC
// SHA-512 of the raw body with the secret key), and a charge is verified
// with Paystack again before it counts.
//
// Deploy:  supabase functions deploy paystack-webhook --no-verify-jwt
// Secrets: PAYSTACK_SECRET_KEY (shared with paystack-payment)
// Paystack: Settings → API Keys & Webhooks → Webhook URL:
//   https://<project-ref>.supabase.co/functions/v1/paystack-webhook

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  type Checkout,
  type Item,
  PAYSTACK_SECRET_KEY,
  recordCardCountry,
  refundedSoFar,
  settleCheckout,
  verifyTransaction,
} from '../_shared/paystack.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function signatureOf(body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(PAYSTACK_SECRET_KEY),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return Array.from(new Uint8Array(mac), (b) => b.toString(16).padStart(2, '0')).join('');
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!PAYSTACK_SECRET_KEY) {
    console.error('paystack-webhook: PAYSTACK_SECRET_KEY is not set');
    return json({ error: 'not_configured' }, 503);
  }

  const raw = await req.text();
  const given = (req.headers.get('x-paystack-signature') ?? '').toLowerCase();
  if (!given || !sameText(given, await signatureOf(raw))) {
    return json({ error: 'bad_signature' }, 401);
  }

  let event: Item;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const data: Item = event?.data ?? {};

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  async function checkoutFor(reference: unknown): Promise<Checkout | null> {
    if (typeof reference !== 'string' || reference === '') return null;
    const { data: row, error } = await admin
      .from('paystack_checkouts')
      .select('reference, request_id, user_id, amount, currency')
      .eq('reference', reference)
      .maybeSingle();
    if (error) throw error;
    return row as Checkout | null;
  }

  try {
    switch (event?.event) {
      case 'charge.success': {
        const checkout = await checkoutFor(data.reference);
        // Not one of ours (another product on the same Paystack account).
        if (!checkout) return json({ ok: true, ignored: true });
        const transaction = await verifyTransaction(checkout.reference);
        if (!transaction) return json({ ok: true, ignored: true });
        const result = await settleCheckout(admin, checkout, transaction);
        if (result === 'paid') await recordCardCountry(admin, checkout.reference, transaction);
        return json({ ok: true, result });
      }
      case 'refund.processed': {
        const checkout = await checkoutFor(
          data.transaction_reference ?? data.transaction?.reference,
        );
        if (!checkout) return json({ ok: true, ignored: true });

        // Paystack sends the refunded amount in the minor unit, like the
        // checkout's own amount (sometimes as a string).
        const raw = data.amount;
        const refundedAmount = raw === undefined || raw === null || raw === ''
          ? NaN
          : Number(raw);
        if (Number.isFinite(refundedAmount) && refundedAmount < checkout.amount) {
          // A transaction can be refunded in parts. Paystack's own list of
          // its processed refunds is added up, so each counts once however
          // often its webhook comes, and the one that reaches the full
          // amount refunds the checkout.
          const transaction = await verifyTransaction(checkout.reference);
          const total = Math.max(
            refundedAmount,
            await refundedSoFar(transaction?.id ?? data.transaction?.id),
          );
          if (total < checkout.amount) {
            console.log('paystack-webhook: partial refund, session stays paid',
              checkout.reference, total, checkout.amount);
            return json({ ok: true, partial: true });
          }
        }

        const { error: markError } = await admin.from('paystack_checkouts')
          .update({ refunded_at: new Date().toISOString() })
          .eq('reference', checkout.reference)
          .is('refunded_at', null);
        if (markError) throw markError;
        if (!checkout.user_id) return json({ ok: true, refunded: 0 });
        const { data: changed, error } = await admin.rpc('record_therapy_refunds', {
          p_user_id: checkout.user_id,
          p_refs: [`paystack:${checkout.reference}`],
        });
        if (error) throw error;
        return json({ ok: true, refunded: Number(changed ?? 0) });
      }
      default:
        return json({ ok: true, ignored: true });
    }
  } catch (error) {
    // A 5xx makes Paystack retry later.
    console.error('paystack-webhook: failed', event?.event, error);
    return json({ error: 'failed' }, 500);
  }
});
