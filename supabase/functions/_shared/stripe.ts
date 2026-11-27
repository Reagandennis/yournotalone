// Stripe, shared by org-billing and stripe-webhook (MindPillars for Work:
// companies paying per seat, migration 0040).
//
// Plain fetch against the REST API (form-encoded), no SDK. The pure parts
// — form encoding, the per-seat price, webhook signatures, reading a
// subscription — are exported for stripe_test.ts.

export const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY');
export const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET');

const STRIPE_API = 'https://api.stripe.com/v1';

// deno-lint-ignore no-explicit-any
export type Item = Record<string, any>;

export class StripeError extends Error {
  constructor(readonly status: number, readonly body: string) {
    super(`Stripe ${status}: ${body}`);
  }
}

type Params = { [key: string]: Param };
type Param = string | number | boolean | null | undefined | Param[] | Params;

/// Stripe's form encoding: nested keys as a[b][c], arrays as a[0][b].
/// null / undefined are left out.
export function formEncode(params: Params): string {
  const out = new URLSearchParams();
  const walk = (prefix: string, value: Param) => {
    if (value === null || value === undefined) return;
    if (Array.isArray(value)) {
      value.forEach((v, i) => walk(`${prefix}[${i}]`, v));
    } else if (typeof value === 'object') {
      for (const [k, v] of Object.entries(value)) walk(prefix ? `${prefix}[${k}]` : k, v);
    } else {
      out.append(prefix, String(value));
    }
  };
  walk('', params);
  return out.toString();
}

export async function stripe(
  method: 'GET' | 'POST' | 'DELETE',
  path: string,
  params: Params = {},
  idempotencyKey?: string,
): Promise<Item> {
  const body = formEncode(params);
  const url = method === 'GET' && body ? `${STRIPE_API}${path}?${body}` : `${STRIPE_API}${path}`;
  const headers: Record<string, string> = {
    Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
    Accept: 'application/json',
  };
  if (method !== 'GET') headers['Content-Type'] = 'application/x-www-form-urlencoded';
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
  const response = await fetch(url, { method, headers, body: method === 'GET' ? undefined : body });
  const text = await response.text();
  if (!response.ok) throw new StripeError(response.status, text);
  return JSON.parse(text);
}

/// What one seat costs per billing period, in cents: the monthly list
/// price, or twelve months less the yearly discount.
export function unitAmount(pepmMinor: number, interval: 'month' | 'year', annualDiscount: number): number {
  const pepm = Math.max(0, Math.round(Number(pepmMinor) || 0));
  if (interval === 'month') return pepm;
  const discount = Math.min(0.9, Math.max(0, Number(annualDiscount) || 0));
  return Math.round(pepm * 12 * (1 - discount));
}

/// Stripe's trial_end for a checkout: the company's own trial end, if it's
/// more than 48 hours away (Stripe wants it at least that far out), so the
/// card isn't charged before the trial is over. Seconds since the epoch.
export function trialEndFor(trialEndsAt: string | null | undefined, nowMs = Date.now()): number | null {
  if (!trialEndsAt) return null;
  const t = Date.parse(trialEndsAt);
  if (!Number.isFinite(t) || t <= nowMs + 48 * 3600 * 1000) return null;
  return Math.floor(t / 1000);
}

/// Seats a company may choose: 5–100 for self-serve; a contract any
/// number from who has joined (and at least 1) upwards. Never below joined.
export function seatsProblem(seats: unknown, plan: string, joined: number): string | null {
  if (typeof seats !== 'number' || !Number.isInteger(seats)) return 'Choose a whole number of seats.';
  if (plan === 'self_serve' && (seats < 5 || seats > 100)) {
    return 'Choose between 5 and 100 seats. For more, contact us.';
  }
  if (seats < 1 || seats > 1000000) return 'That number of seats isn’t possible.';
  if (seats < joined) return 'More people have joined than that. Remove people first, or keep more seats.';
  return null;
}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)));
}

/// Compares in time that depends only on the length.
export function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// Checks a Stripe-Signature header ("t=…,v1=…[,v1=…]") against the raw
/// body: HMAC-SHA256 of "<t>.<body>" with the endpoint's signing secret,
/// signed within toleranceSeconds of now.
export async function verifyStripeSignature(
  rawBody: string,
  header: string | null,
  secret: string,
  toleranceSeconds = 300,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  if (!header || !secret) return false;
  let timestamp = NaN;
  const signatures: string[] = [];
  for (const part of header.split(',')) {
    const [k, ...rest] = part.trim().split('=');
    const v = rest.join('=');
    if (k === 't') timestamp = Number(v);
    else if (k === 'v1' && v) signatures.push(v.toLowerCase());
  }
  if (!Number.isFinite(timestamp) || signatures.length === 0) return false;
  if (Math.abs(nowSeconds - timestamp) > toleranceSeconds) return false;
  const expected = await hmacSha256Hex(secret, `${timestamp}.${rawBody}`);
  let ok = false;
  for (const s of signatures) ok = sameText(s, expected) || ok;
  return ok;
}

/// Builds a header the way Stripe does (for tests).
export async function signStripePayload(rawBody: string, secret: string, timestamp: number): Promise<string> {
  return `t=${timestamp},v1=${await hmacSha256Hex(secret, `${timestamp}.${rawBody}`)}`;
}

function idOf(value: unknown): string | null {
  if (typeof value === 'string' && value) return value;
  if (value && typeof value === 'object' && typeof (value as Item).id === 'string') return (value as Item).id;
  return null;
}

/// The subscription an event is about, whichever API version shaped it.
export function subscriptionIdOf(event: Item): string | null {
  const object: Item = event?.data?.object ?? {};
  switch (event?.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted':
      return idOf(object.id);
    case 'checkout.session.completed':
      return object.mode === 'subscription' ? idOf(object.subscription) : null;
    case 'invoice.paid':
    case 'invoice.payment_failed':
      return idOf(object.subscription) ??
        idOf(object.parent?.subscription_details?.subscription) ??
        idOf(object.lines?.data?.[0]?.parent?.subscription_item_details?.subscription) ??
        idOf(object.lines?.data?.[0]?.subscription);
    default:
      return null;
  }
}

/// The arguments for org_billing_apply from a subscription (as Stripe
/// returns it), or null when it isn't one of ours (no org_id metadata).
export function billingFromSubscription(sub: Item, fallbackOrgId?: string | null): {
  p_org: string;
  p_customer: string | null;
  p_subscription: string;
  p_stripe_status: string;
  p_seats: number | null;
  p_interval: string | null;
  p_period_end: string | null;
} | null {
  const orgId = sub?.metadata?.org_id || fallbackOrgId;
  if (!orgId || !/^[0-9a-f-]{36}$/i.test(orgId) || typeof sub?.id !== 'string') return null;
  const item: Item = sub.items?.data?.[0] ?? {};
  const quantity = Number(item.quantity ?? sub.quantity);
  const interval = item.price?.recurring?.interval ?? item.plan?.interval ?? null;
  // Older API versions keep the period on the subscription, newer on the item.
  const periodEnd = sub.status === 'trialing' && sub.trial_end
    ? sub.trial_end
    : (sub.current_period_end ?? item.current_period_end ?? null);
  return {
    p_org: orgId,
    p_customer: idOf(sub.customer),
    p_subscription: sub.id,
    p_stripe_status: String(sub.status ?? ''),
    p_seats: Number.isInteger(quantity) && quantity > 0 ? quantity : null,
    p_interval: interval === 'month' || interval === 'year' ? interval : null,
    p_period_end: typeof periodEnd === 'number' ? new Date(periodEnd * 1000).toISOString() : null,
  };
}
