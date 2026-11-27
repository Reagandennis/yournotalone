// deno test --allow-env supabase/functions/_shared/stripe_test.ts
import { assert, assertEquals, assertFalse } from 'jsr:@std/assert@1';
import {
  billingFromSubscription,
  formEncode,
  seatsProblem,
  signStripePayload,
  subscriptionIdOf,
  trialEndFor,
  unitAmount,
  verifyStripeSignature,
} from './stripe.ts';

const SECRET = 'whsec_test_secret';
const BODY = '{"id":"evt_1","type":"invoice.paid"}';
const NOW = 1_800_000_000;

Deno.test('signature: a fresh, correct signature passes', async () => {
  const header = await signStripePayload(BODY, SECRET, NOW - 10);
  assert(await verifyStripeSignature(BODY, header, SECRET, 300, NOW));
});

Deno.test('signature: any of several v1 signatures may match (secret rotation)', async () => {
  const good = await signStripePayload(BODY, SECRET, NOW);
  const v1 = good.split('v1=')[1];
  assert(await verifyStripeSignature(BODY, `t=${NOW},v1=${'0'.repeat(64)},v1=${v1}`, SECRET, 300, NOW));
});

Deno.test('signature: wrong secret, changed body, old or future timestamp fail', async () => {
  const header = await signStripePayload(BODY, SECRET, NOW);
  assertFalse(await verifyStripeSignature(BODY, header, 'whsec_other', 300, NOW));
  assertFalse(await verifyStripeSignature(BODY + ' ', header, SECRET, 300, NOW));
  assertFalse(await verifyStripeSignature(BODY, header, SECRET, 300, NOW + 301));
  assertFalse(await verifyStripeSignature(BODY, header, SECRET, 300, NOW - 301));
  assert(await verifyStripeSignature(BODY, header, SECRET, 300, NOW + 300));
});

Deno.test('signature: missing or malformed headers fail', async () => {
  assertFalse(await verifyStripeSignature(BODY, null, SECRET, 300, NOW));
  assertFalse(await verifyStripeSignature(BODY, '', SECRET, 300, NOW));
  assertFalse(await verifyStripeSignature(BODY, `t=${NOW}`, SECRET, 300, NOW));
  assertFalse(await verifyStripeSignature(BODY, 'v1=abc', SECRET, 300, NOW));
  const v0only = (await signStripePayload(BODY, SECRET, NOW)).replace('v1=', 'v0=');
  assertFalse(await verifyStripeSignature(BODY, v0only, SECRET, 300, NOW));
  assertFalse(await verifyStripeSignature(BODY, await signStripePayload(BODY, SECRET, NOW), '', 300, NOW));
});

Deno.test('price: monthly is the list price per seat', () => {
  assertEquals(unitAmount(600, 'month', 0.15), 600);
  assertEquals(unitAmount(250, 'month', 0.5), 250);
});

Deno.test('price: yearly is twelve months less the discount, rounded', () => {
  assertEquals(unitAmount(600, 'year', 0.15), 6120);
  assertEquals(unitAmount(250, 'year', 0.15), 2550);
  assertEquals(unitAmount(333, 'year', 0.15), Math.round(333 * 12 * 0.85));
  assertEquals(unitAmount(600, 'year', 0), 7200);
  assertEquals(unitAmount(600, 'year', 5), Math.round(7200 * 0.1)); // discount capped at 90%
  assertEquals(unitAmount(-5, 'month', 0), 0);
});

Deno.test('trial: carried into Stripe only if more than 48 hours away', () => {
  const now = Date.parse('2026-11-27T00:00:00Z');
  assertEquals(trialEndFor('2026-12-10T00:00:00Z', now), Date.parse('2026-12-10T00:00:00Z') / 1000);
  assertEquals(trialEndFor('2026-11-28T23:00:00Z', now), null);
  assertEquals(trialEndFor('2026-11-01T00:00:00Z', now), null);
  assertEquals(trialEndFor(null, now), null);
  assertEquals(trialEndFor('not a date', now), null);
});

Deno.test('seats: self-serve 5–100, contract from joined, never below joined', () => {
  assertEquals(seatsProblem(5, 'self_serve', 0), null);
  assertEquals(seatsProblem(100, 'self_serve', 0), null);
  assert(seatsProblem(4, 'self_serve', 0));
  assert(seatsProblem(101, 'self_serve', 0));
  assert(seatsProblem(10, 'self_serve', 11));
  assertEquals(seatsProblem(500, 'contract', 120), null);
  assertEquals(seatsProblem(2, 'contract', 2), null);
  assert(seatsProblem(119, 'contract', 120));
  assert(seatsProblem(5.5, 'self_serve', 0));
  assert(seatsProblem('10', 'self_serve', 0));
});

Deno.test('form encoding: nested objects and arrays, nulls left out', () => {
  const body = formEncode({
    mode: 'subscription',
    line_items: [{ quantity: 7, price_data: { currency: 'usd', unit_amount: 600, recurring: { interval: 'month' } } }],
    subscription_data: { metadata: { org_id: 'abc' }, trial_end: null },
  });
  const p = new URLSearchParams(body);
  assertEquals(p.get('mode'), 'subscription');
  assertEquals(p.get('line_items[0][quantity]'), '7');
  assertEquals(p.get('line_items[0][price_data][recurring][interval]'), 'month');
  assertEquals(p.get('subscription_data[metadata][org_id]'), 'abc');
  assertFalse(p.has('subscription_data[trial_end]'));
});

Deno.test('events: the subscription id, whichever event and API version', () => {
  assertEquals(subscriptionIdOf({ type: 'customer.subscription.updated', data: { object: { id: 'sub_1' } } }), 'sub_1');
  assertEquals(subscriptionIdOf({ type: 'checkout.session.completed', data: { object: { mode: 'subscription', subscription: 'sub_2' } } }), 'sub_2');
  assertEquals(subscriptionIdOf({ type: 'checkout.session.completed', data: { object: { mode: 'payment' } } }), null);
  assertEquals(subscriptionIdOf({ type: 'invoice.paid', data: { object: { subscription: 'sub_3' } } }), 'sub_3');
  assertEquals(subscriptionIdOf({
    type: 'invoice.payment_failed',
    data: { object: { parent: { subscription_details: { subscription: 'sub_4' } } } },
  }), 'sub_4');
  assertEquals(subscriptionIdOf({ type: 'charge.succeeded', data: { object: { id: 'ch_1' } } }), null);
});

Deno.test('subscription → org_billing_apply arguments', () => {
  const org = '11111111-2222-3333-4444-555555555555';
  const a = billingFromSubscription({
    id: 'sub_1', customer: 'cus_1', status: 'active', metadata: { org_id: org },
    items: { data: [{ quantity: 12, price: { recurring: { interval: 'year' } }, current_period_end: NOW }] },
  });
  assertEquals(a, {
    p_org: org, p_customer: 'cus_1', p_subscription: 'sub_1', p_stripe_status: 'active',
    p_seats: 12, p_interval: 'year', p_period_end: new Date(NOW * 1000).toISOString(),
  });
  const trial = billingFromSubscription({
    id: 'sub_2', customer: { id: 'cus_2' }, status: 'trialing', trial_end: NOW + 5, current_period_end: NOW,
    metadata: {}, items: { data: [{ quantity: 5, plan: { interval: 'month' } }] },
  }, org);
  assertEquals(trial?.p_period_end, new Date((NOW + 5) * 1000).toISOString());
  assertEquals(trial?.p_customer, 'cus_2');
  assertEquals(trial?.p_org, org);
  assertEquals(billingFromSubscription({ id: 'sub_3', status: 'active', metadata: {} }), null);
  assertEquals(billingFromSubscription({ id: 'sub_4', status: 'active', metadata: { org_id: 'nope' } }), null);
});
