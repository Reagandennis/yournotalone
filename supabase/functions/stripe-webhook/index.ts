// Hears from Stripe about companies' subscriptions (MindPillars for Work,
// migration 0040).
//
//   checkout.session.completed      (mode subscription)
//   customer.subscription.created / .updated / .deleted
//   invoice.paid / invoice.payment_failed
//
// For each, the subscription is fetched from Stripe again — events can
// arrive late and out of order, so the current state is what counts — and
// passed to org_billing_apply (status, seats, interval, period end,
// customer), found by the org_id in its metadata (org-billing sets it; a
// checkout's own metadata / client_reference_id is the fallback). That is
// safe to repeat, so a retried event does no harm; an event about a
// subscription the company has since replaced is ignored by
// org_billing_apply. Anything else, or a subscription that isn't a
// company's, is 200 { ignored: true }.
//
// Every event is checked against the Stripe-Signature header (HMAC
// SHA-256 of "<timestamp>.<raw body>" with the endpoint's signing secret,
// within 5 minutes): 400 bad_signature otherwise. A 5xx makes Stripe retry.
//
// Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: STRIPE_SECRET_KEY (shared with org-billing)
//          STRIPE_WEBHOOK_SECRET  the endpoint's signing secret (whsec_…)
// Stripe: Developers → Webhooks → Add endpoint:
//   https://<project-ref>.supabase.co/functions/v1/stripe-webhook
//   with the six events above.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  billingFromSubscription,
  type Item,
  stripe,
  StripeError,
  STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET,
  subscriptionIdOf,
  verifyStripeSignature,
} from '../_shared/stripe.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const HANDLED = new Set([
  'checkout.session.completed',
  'customer.subscription.created',
  'customer.subscription.updated',
  'customer.subscription.deleted',
  'invoice.paid',
  'invoice.payment_failed',
]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!STRIPE_WEBHOOK_SECRET || !STRIPE_SECRET_KEY) {
    console.error('stripe-webhook: STRIPE_WEBHOOK_SECRET / STRIPE_SECRET_KEY not set');
    return json({ error: 'billing_not_configured' }, 503);
  }

  const raw = await req.text();
  if (!(await verifyStripeSignature(raw, req.headers.get('Stripe-Signature'), STRIPE_WEBHOOK_SECRET))) {
    return json({ error: 'bad_signature' }, 400);
  }

  let event: Item;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (!HANDLED.has(event?.type)) return json({ ok: true, ignored: true });

  const subscriptionId = subscriptionIdOf(event);
  if (!subscriptionId) return json({ ok: true, ignored: true });
  const object: Item = event.data?.object ?? {};
  const fallbackOrg = event.type === 'checkout.session.completed'
    ? (object.metadata?.org_id ?? object.client_reference_id ?? null)
    : null;

  try {
    const sub = await stripe('GET', `/subscriptions/${encodeURIComponent(subscriptionId)}`);
    const args = billingFromSubscription(sub, fallbackOrg);
    if (!args) return json({ ok: true, ignored: true });

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error } = await admin.rpc('org_billing_apply', args);
    if (error) throw error;
    return json({ ok: true, org_id: args.p_org, status: args.p_stripe_status });
  } catch (error) {
    // A subscription Stripe doesn't know (another account's test event).
    if (error instanceof StripeError && error.status === 404) return json({ ok: true, ignored: true });
    console.error('stripe-webhook: failed', event.type, event.id, error);
    return json({ error: 'failed' }, 500);
  }
});
