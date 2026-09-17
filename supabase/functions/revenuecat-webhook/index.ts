// Hears about refunds from RevenueCat, so a refunded session stops being
// "paid" and joinable.
//
// RevenueCat POSTs every event here. The event itself is only a nudge: on
// any event about a customer this re-reads their purchases from RevenueCat
// API v2 (as confirm-session-payment does) and hands the refunded purchase
// ids to record_therapy_refunds, which puts the matching sessions back to
// unpaid and emails the care team and the client. The purchases that aren't
// refunded go to record_therapy_refund_reversals, so a refund Google later
// reverses makes the session paid again. Nothing in the payload is trusted
// beyond the customer id, which is only used to look them up.
//
// Deploy:  supabase functions deploy revenuecat-webhook --no-verify-jwt
//          (RevenueCat doesn't send a Supabase JWT; the shared secret below
//          is what authenticates it)
// Secrets: REVENUECAT_WEBHOOK_SECRET   any long random string, e.g.
//                                      openssl rand -hex 32
//          REVENUECAT_SECRET_KEY       as for confirm-session-payment
//          REVENUECAT_PROJECT_ID
//          THERAPY_SESSION_PRODUCT_ID  optional, defaults to therapy
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.
//
// RevenueCat dashboard → Integrations → Webhooks → Add new configuration:
//   URL                         https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//   Authorization header value  Bearer <REVENUECAT_WEBHOOK_SECRET>
//   Environment                 Production (and Sandbox while testing)
//   Event types                 all, or at least CANCELLATION, REFUND_REVERSED,
//                               NON_RENEWING_PURCHASE and TRANSFER
// RevenueCat expects a 200 and retries anything else five times over about
// two and a half hours, so a RevenueCat outage answers 502 and gets retried.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
const REVENUECAT_SECRET_KEY = Deno.env.get('REVENUECAT_SECRET_KEY');
const REVENUECAT_PROJECT_ID = Deno.env.get('REVENUECAT_PROJECT_ID');

const REVENUECAT_API = 'https://api.revenuecat.com/v2';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Same length or not, the comparison takes the same time.
function sameSecret(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
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
    next = body.next_page
      ? String(body.next_page).replace(/^(https?:\/\/[^/]+)?\/v2/, '')
      : null;
  }
  return items;
}

// The app logs RevenueCat in with the Supabase user id, so among the ids
// RevenueCat knows this customer by, the UUID-shaped ones are ours.
function customerIds(event: Item): string[] {
  const ids = new Set<string>();
  for (const id of [event.app_user_id, event.original_app_user_id, ...(event.aliases ?? [])]) {
    if (typeof id === 'string' && UUID.test(id)) ids.add(id.toLowerCase());
  }
  return [...ids];
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  if (!WEBHOOK_SECRET) {
    console.error('revenuecat-webhook: REVENUECAT_WEBHOOK_SECRET is not set');
    return json({ error: 'not_configured' }, 503);
  }
  const given = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!sameSecret(given, WEBHOOK_SECRET)) return json({ error: 'unauthorized' }, 401);

  let event: Item;
  try {
    const body = await req.json();
    event = body?.event;
    if (!event || typeof event !== 'object') throw new Error('no event');
  } catch {
    return json({ error: 'bad_request' }, 400);
  }

  const type = String(event.type ?? '');
  const ids = customerIds(event);
  console.log('revenuecat-webhook:', type, event.id, ids.join(',') || '(no customer)');
  if (ids.length === 0 || type === 'TEST') return json({ ok: true, ignored: true });

  if (!REVENUECAT_SECRET_KEY || !REVENUECAT_PROJECT_ID) {
    console.error('revenuecat-webhook: RevenueCat secrets are not set');
    return json({ error: 'not_configured' }, 503);
  }
  const project = `/projects/${encodeURIComponent(REVENUECAT_PROJECT_ID)}`;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let refunded = 0;
  let reversed = 0;
  for (const userId of ids) {
    let purchases: Item[];
    try {
      purchases = await listAll(
        `${project}/customers/${encodeURIComponent(userId)}/purchases?limit=100`,
      );
    } catch (error) {
      // A customer RevenueCat has never seen has bought nothing.
      if (error instanceof RevenueCatError && error.status === 404) continue;
      console.error('revenuecat-webhook: RevenueCat lookup failed', userId, error);
      return json({ error: 'verification_failed' }, 502);
    }

    const isRefunded = (p: Item) => p.status === 'refunded' || p.refunded_at != null;
    const refundedRefs = purchases.filter(isRefunded).map((p) => `revenuecat:${p.id}`);
    const activeRefs = purchases.filter((p) => !isRefunded(p)).map((p) => `revenuecat:${p.id}`);

    for (const [fn, refs] of [
      ['record_therapy_refunds', refundedRefs],
      ['record_therapy_refund_reversals', activeRefs],
    ] as const) {
      if (refs.length === 0) continue;
      const { data, error } = await admin.rpc(fn, { p_user_id: userId, p_refs: refs });
      if (error) {
        console.error(`revenuecat-webhook: ${fn} failed`, userId, error);
        return json({ error: 'update_failed' }, 500);
      }
      if (fn === 'record_therapy_refunds') refunded += Number(data ?? 0);
      else reversed += Number(data ?? 0);
    }
  }

  if (refunded > 0) console.log('revenuecat-webhook: sessions set back to unpaid:', refunded);
  if (reversed > 0) console.log('revenuecat-webhook: sessions paid again:', reversed);
  return json({ ok: true, refunded, reversed });
});
