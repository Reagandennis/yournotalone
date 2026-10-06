// Hears from Paystack about therapy session payments.
//
//   charge.success     marks the session paid, the same way paystack-payment
//                      does, so a payment lands even if the app closed
//                      before confirming it.
//   refund.processed   puts the session back to unpaid through
//                      record_therapy_refunds (migration 0012, worded for
//                      Paystack in 0021), which emails the care team and
//                      the client.
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
        return json({ ok: true, result });
      }
      case 'refund.processed': {
        const checkout = await checkoutFor(
          data.transaction_reference ?? data.transaction?.reference,
        );
        if (!checkout) return json({ ok: true, ignored: true });
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
