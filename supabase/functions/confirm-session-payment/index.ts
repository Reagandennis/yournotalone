// Marks a therapy session paid once RevenueCat confirms the purchase.
//
// Every session after someone's free first one is bought in the app as a
// one-time Google Play product, through RevenueCat. The app calls this after
// buying (and again from "Already paid?"). The app's word is never taken for
// it: this reads RevenueCat's own record of the caller's purchases, through
// RevenueCat API v2. Each purchase pays for exactly one session — its
// RevenueCat purchase id goes into therapy_requests.payment_ref, which is
// unique.
//
// Deploy:  supabase functions deploy confirm-session-payment
// Secrets: REVENUECAT_SECRET_KEY       RevenueCat → Project settings → API keys:
//                                      a v2 secret key that can read customer
//                                      information and products
//          REVENUECAT_PROJECT_ID       proj…, the RevenueCat project
//          THERAPY_SESSION_PRODUCT_ID  optional; the store product id,
//                                      defaults to therapy
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const REVENUECAT_SECRET_KEY = Deno.env.get('REVENUECAT_SECRET_KEY');
const REVENUECAT_PROJECT_ID = Deno.env.get('REVENUECAT_PROJECT_ID');
// Keep in step with therapySessionProductId in lib/billing/session_payments.dart.
const PRODUCT_ID = Deno.env.get('THERAPY_SESSION_PRODUCT_ID') ?? 'therapy';

const REVENUECAT_API = 'https://api.revenuecat.com/v2';

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

class RevenueCatError extends Error {
  constructor(readonly status: number, body: string) {
    super(`RevenueCat ${status}: ${body}`);
  }
}

// deno-lint-ignore no-explicit-any
type Item = Record<string, any>;

// Every page of a v2 list endpoint. `path` is relative to /v2.
async function listAll(path: string): Promise<Item[]> {
  const items: Item[] = [];
  let next: string | null = path;
  for (let page = 0; next !== null && page < 20; page++) {
    const response: Response = await fetch(`${REVENUECAT_API}${next}`, {
      headers: {
        Authorization: `Bearer ${REVENUECAT_SECRET_KEY}`,
        Accept: 'application/json',
      },
    });
    if (!response.ok) throw new RevenueCatError(response.status, await response.text());
    const body = await response.json();
    items.push(...(body.items ?? []));
    // next_page comes back as a URL; keep only the part after /v2.
    next = body.next_page
      ? String(body.next_page).replace(/^(https?:\/\/[^/]+)?\/v2/, '')
      : null;
  }
  return items;
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
  try {
    const body = await req.json();
    requestId = typeof body?.request_id === 'string' ? body.request_id : '';
  } catch {
    // Falls through to the check below.
  }
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return json({ error: 'bad_request' }, 400);

  const { data: session, error: sessionError } = await admin
    .from('therapy_requests')
    .select('id, user_id, status, payment_status')
    .eq('id', requestId)
    .maybeSingle();
  if (sessionError) {
    console.error('confirm-session-payment: lookup failed', requestId, sessionError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (!session || session.user_id !== user.id) return json({ error: 'not_found' }, 404);
  if (session.payment_status !== 'unpaid') return json({ paid: true });
  if (!['pending', 'confirmed'].includes(session.status)) {
    return json({ error: 'not_payable' }, 409);
  }

  if (!REVENUECAT_SECRET_KEY || !REVENUECAT_PROJECT_ID) {
    console.error('confirm-session-payment: RevenueCat secrets are not set');
    return json({ error: 'not_configured' }, 503);
  }
  const project = `/projects/${encodeURIComponent(REVENUECAT_PROJECT_ID)}`;

  let purchases: Item[];
  try {
    // RevenueCat ids its products itself; find the ones behind the store id.
    // Newer Play one-time products can carry a purchase option after a colon.
    const products = await listAll(`${project}/products?limit=100`);
    const productIds = new Set(
      products
        .filter((p) => p.store_identifier === PRODUCT_ID ||
          String(p.store_identifier ?? '').startsWith(`${PRODUCT_ID}:`))
        .map((p) => p.id),
    );
    if (productIds.size === 0) {
      console.error('confirm-session-payment: no RevenueCat product for', PRODUCT_ID);
      return json({ error: 'not_configured' }, 503);
    }

    // The app logs RevenueCat in with the Supabase user id, so that is the
    // RevenueCat customer id too.
    try {
      const all = await listAll(
        `${project}/customers/${encodeURIComponent(user.id)}/purchases?limit=100`,
      );
      purchases = all.filter((p) => productIds.has(p.product_id) && p.status !== 'refunded');
    } catch (error) {
      // A customer RevenueCat has never seen has bought nothing.
      if (error instanceof RevenueCatError && error.status === 404) purchases = [];
      else throw error;
    }
  } catch (error) {
    console.error('confirm-session-payment: RevenueCat lookup failed', error);
    return json({ error: 'verification_failed' }, 502);
  }

  const { data: usedRows, error: usedError } = await admin
    .from('therapy_requests')
    .select('payment_ref')
    .eq('user_id', user.id)
    .like('payment_ref', 'revenuecat:%');
  if (usedError) {
    console.error('confirm-session-payment: used lookup failed', usedError);
    return json({ error: 'lookup_failed' }, 500);
  }
  const used = new Set((usedRows ?? []).map((row) => row.payment_ref));

  // Oldest unused purchase first, so a payment that never got attached to
  // its session (the app closed mid-way) is the one that gets used.
  const unused = purchases
    .filter((purchase) => !used.has(`revenuecat:${purchase.id}`))
    .sort((a, b) => Number(a.purchased_at) - Number(b.purchased_at));

  for (const purchase of unused) {
    const { error: updateError } = await admin
      .from('therapy_requests')
      .update({
        payment_status: 'paid',
        payment_ref: `revenuecat:${purchase.id}`,
        paid_at: new Date().toISOString(),
      })
      .eq('id', session.id)
      .eq('payment_status', 'unpaid');
    // Another session claimed this purchase a moment ago; try the next one.
    if (updateError?.code === '23505') continue;
    if (updateError) {
      console.error('confirm-session-payment: update failed', session.id, updateError);
      return json({ error: 'update_failed' }, 500);
    }
    return json({ paid: true });
  }

  return json({ error: 'no_payment_found' }, 402);
});
