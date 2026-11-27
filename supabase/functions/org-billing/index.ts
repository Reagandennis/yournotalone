// Billing for MindPillars for Work (companies paying per seat, migration
// 0040), called by the HR portal at https://sso.mindpillars.app/portal.
//
// The caller must be one of the company's HR admins (or the care team):
// org_is_admin is asked with the caller's own token. Body
// { action, org_id, … }:
//   action "checkout" { interval?: 'month' | 'year' }
//                     opens a Stripe Checkout for a subscription: one line,
//                     the company's per-seat price (monthly, or twelve
//                     months less its yearly discount) × its seats. A trial
//                     still more than 48 hours from its end carries on in
//                     Stripe, so the card isn't charged before it ends.
//                     → { url }. A company that already has a subscription
//                     gets the billing portal instead: { url, portal: true }.
//   action "portal"   Stripe's billing portal (card, invoices, cancel)
//                     → { url }; 409 no_billing before the first checkout.
//   action "seats"    { seats }: 5–100 for self-serve, a contract any number
//                     from who has joined. With a subscription, Stripe's
//                     quantity changes (prorated) and then the company's row;
//                     without one, org_set_seats as the caller.
//                     → the caller's org_overview.
// Errors: 400 bad_request / { error: 'invalid_seats', message },
// 401 missing_token / invalid_token, 403 not_admin, 404 not_found,
// 502 stripe_failed, 503 billing_not_configured (STRIPE_SECRET_KEY unset;
// the portal says billing isn't open yet).
//
// The subscription's state reaches the database through stripe-webhook
// (org_billing_apply). The customer is saved here as soon as it's made.
//
// Deploy:  supabase functions deploy org-billing
// Secrets: STRIPE_SECRET_KEY   Stripe → Developers → API keys
//                              (sk_test_… while testing, sk_live_… after)
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are
// injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  type Item,
  seatsProblem,
  stripe,
  StripeError,
  STRIPE_SECRET_KEY,
  trialEndFor,
  unitAmount,
} from '../_shared/stripe.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SITE = 'https://sso.mindpillars.app';

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

  const authorization = req.headers.get('Authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'missing_token' }, 401);

  let body: Item = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const action = String(body?.action ?? '');
  const orgId = typeof body?.org_id === 'string' ? body.org_id : '';
  if (!['checkout', 'portal', 'seats'].includes(action) || !/^[0-9a-f-]{36}$/i.test(orgId)) {
    return json({ error: 'bad_request' }, 400);
  }

  // As the caller (their token): RLS and the RPCs' own checks apply.
  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) return json({ error: 'invalid_token' }, 401);

  const { data: isAdmin, error: adminError } = await asUser.rpc('org_is_admin', { p_org: orgId });
  if (adminError) {
    console.error('org-billing: org_is_admin failed', adminError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (isAdmin !== true) return json({ error: 'not_admin' }, 403);

  if (!STRIPE_SECRET_KEY) return json({ error: 'billing_not_configured' }, 503);

  const { data: info, error: infoError } = await admin.rpc('org_billing_info', { p_org: orgId });
  if (infoError) {
    console.error('org-billing: org_billing_info failed', infoError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (!info) return json({ error: 'not_found' }, 404);
  const org = info as Item;

  async function apply(args: Item) {
    const { error } = await admin.rpc('org_billing_apply', { p_org: orgId, ...args });
    if (error) throw error;
  }

  async function portalUrl(customer: string): Promise<string> {
    const session = await stripe('POST', '/billing_portal/sessions', {
      customer,
      return_url: `${SITE}/portal`,
    });
    return session.url;
  }

  try {
    switch (action) {
      case 'checkout': {
        if (org.stripe_subscription_id && org.stripe_customer_id) {
          return json({ url: await portalUrl(org.stripe_customer_id), portal: true });
        }
        const interval: 'month' | 'year' = body.interval === 'year' || body.interval === 'month'
          ? body.interval
          : (org.billing_interval === 'year' ? 'year' : 'month');

        let customer: string | null = org.stripe_customer_id ?? null;
        if (!customer) {
          const created = await stripe('POST', '/customers', {
            email: org.owner_email ?? undefined,
            name: org.name,
            metadata: { org_id: orgId },
          }, `org-customer-${orgId}`);
          customer = created.id as string;
          await apply({ p_customer: customer });
        }

        const amount = unitAmount(org.pepm_minor, interval, org.annual_discount);
        const trialEnd = trialEndFor(org.trial_ends_at);
        const session = await stripe('POST', '/checkout/sessions', {
          mode: 'subscription',
          customer,
          client_reference_id: orgId,
          metadata: { org_id: orgId },
          line_items: [{
            quantity: Math.max(1, Number(org.seats) || 1),
            price_data: {
              currency: 'usd',
              unit_amount: amount,
              recurring: { interval },
              product_data: { name: `MindPillars for Work — ${org.name}` },
            },
          }],
          subscription_data: {
            metadata: { org_id: orgId },
            trial_end: trialEnd,
          },
          success_url: `${SITE}/portal?billing=success`,
          cancel_url: `${SITE}/portal?billing=cancelled`,
        });
        return json({ url: session.url });
      }

      case 'portal': {
        if (!org.stripe_customer_id) return json({ error: 'no_billing' }, 409);
        return json({ url: await portalUrl(org.stripe_customer_id) });
      }

      case 'seats': {
        const seats = Number(body.seats);
        const problem = seatsProblem(seats, String(org.plan ?? 'self_serve'), Number(org.joined ?? 0));
        if (problem) return json({ error: 'invalid_seats', message: problem }, 400);

        if (org.stripe_subscription_id) {
          const sub = await stripe('GET', `/subscriptions/${encodeURIComponent(org.stripe_subscription_id)}`);
          const item = sub.items?.data?.[0];
          if (!item?.id) return json({ error: 'stripe_failed' }, 502);
          if (Number(item.quantity) !== seats) {
            await stripe('POST', `/subscription_items/${encodeURIComponent(item.id)}`, {
              quantity: seats,
              proration_behavior: 'create_prorations',
            });
          }
          await apply({ p_seats: seats });
        } else {
          const { error } = await asUser.rpc('org_set_seats', { p_org: orgId, p_seats: seats });
          if (error) return json({ error: 'invalid_seats', message: error.message }, 400);
        }
        const { data: overview, error } = await asUser.rpc('org_overview', { p_org: orgId });
        if (error) throw error;
        return json(overview);
      }
    }
    return json({ error: 'bad_request' }, 400);
  } catch (error) {
    console.error('org-billing: failed', action, orgId, error);
    if (error instanceof StripeError) return json({ error: 'stripe_failed' }, 502);
    return json({ error: 'failed' }, 500);
  }
});
