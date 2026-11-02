// Is this user premium? (design §5)
//
//   1. JWT `app_metadata.premium_comp === true` -> yes, no network.
//   2. Otherwise RevenueCat API v2: GET /projects/{p}/customers/{user id}
//      returns `active_entitlements.items[]` of {entitlement_id, expires_at}.
//      `entitlement_id` is RevenueCat's internal id (entl…), NOT the lookup
//      key the app uses ("Techgetafrica Pro"), so we compare against
//      PRO_ENTITLEMENT_ID, or resolve the lookup key once via
//      GET /projects/{p}/entitlements.
//
// The answer is cached for 5 min in caches.default (keyed by sha256 of the
// user id; the body is just "true"/"false"), with a small in-isolate copy in
// front of it. Any RevenueCat error or timeout means "not premium" and is
// not cached.

import type { AuthUser, Env } from './env';
import { sha256Hex } from './http';
import { logError } from './log';

const REVENUECAT_API = 'https://api.revenuecat.com/v2';
const TTL_SECONDS = 300;
const RC_TIMEOUT_MS = 3_000;
const MAX_PAGES = 5;
const MEMO_MAX = 1_000;

class RevenueCatError extends Error {
  constructor(readonly status: number) {
    super(`RevenueCat HTTP ${status}`);
  }
}

// In-isolate L1 cache: hashed user id -> {premium, until}.
const memo = new Map<string, { premium: boolean; until: number }>();
// Lookup key -> internal entitlement id, resolved once per isolate.
const resolvedEntitlementIds = new Map<string, string>();

/** Test hook. */
export function resetPremiumState(): void {
  memo.clear();
  resolvedEntitlementIds.clear();
}

function cacheKey(hash: string): string {
  // Synthetic URL; never fetched. Only used as a Cache API key.
  return `https://premium-cache.yournotalone.internal/v1/${hash}`;
}

export async function isPremium(user: AuthUser, env: Env): Promise<boolean> {
  if (user.premiumComp) return true;

  const hash = await sha256Hex(user.id);
  const now = Date.now();
  const hit = memo.get(hash);
  if (hit && hit.until > now) return hit.premium;

  const cache = caches.default;
  const key = cacheKey(hash);
  try {
    const cached = await cache.match(key);
    if (cached) {
      const premium = (await cached.text()) === 'true';
      remember(hash, premium, now);
      return premium;
    }
  } catch (error) {
    logError('premium_cache_read_failed', error);
  }

  let premium: boolean;
  try {
    premium = await revenueCatHasPro(user.id, env);
  } catch (error) {
    // Fail closed, and don't cache the failure.
    logError('revenuecat_check_failed', error);
    return false;
  }

  remember(hash, premium, now);
  try {
    await cache.put(
      key,
      new Response(premium ? 'true' : 'false', {
        headers: { 'Cache-Control': `max-age=${TTL_SECONDS}`, 'Content-Type': 'text/plain' },
      }),
    );
  } catch (error) {
    logError('premium_cache_write_failed', error);
  }
  return premium;
}

function remember(hash: string, premium: boolean, now: number): void {
  if (memo.size >= MEMO_MAX) memo.clear();
  memo.set(hash, { premium, until: now + TTL_SECONDS * 1000 });
}

async function rcGet(path: string, env: Env): Promise<any> {
  const response = await fetch(`${REVENUECAT_API}${path}`, {
    headers: {
      Authorization: `Bearer ${env.REVENUECAT_SECRET_KEY}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(RC_TIMEOUT_MS),
  });
  if (!response.ok) throw new RevenueCatError(response.status);
  return response.json();
}

/** next_page comes back as "/v2/projects/…" or a full URL; keep the part after /v2. */
function nextPath(next: unknown): string | null {
  return typeof next === 'string' && next ? next.replace(/^(https?:\/\/[^/]+)?\/v2/, '') : null;
}

async function proEntitlementId(env: Env, project: string): Promise<string> {
  const configured = env.PRO_ENTITLEMENT_ID?.trim();
  if (configured) return configured;

  const lookupKey = env.PRO_ENTITLEMENT_LOOKUP_KEY?.trim() || 'Techgetafrica Pro';
  const known = resolvedEntitlementIds.get(lookupKey);
  if (known) return known;

  // Needs the key permission project_configuration:entitlements:read.
  let path: string | null = `${project}/entitlements?limit=100`;
  for (let page = 0; path && page < MAX_PAGES; page++) {
    const body = await rcGet(path, env);
    for (const e of body?.items ?? []) {
      if (e?.lookup_key === lookupKey && typeof e.id === 'string') {
        resolvedEntitlementIds.set(lookupKey, e.id);
        return e.id;
      }
    }
    path = nextPath(body?.next_page);
  }
  throw new Error(`RevenueCat entitlement "${lookupKey}" not found`);
}

async function revenueCatHasPro(userId: string, env: Env): Promise<boolean> {
  if (!env.REVENUECAT_SECRET_KEY || !env.REVENUECAT_PROJECT_ID) {
    throw new Error('RevenueCat secrets are not set');
  }
  const project = `/projects/${encodeURIComponent(env.REVENUECAT_PROJECT_ID)}`;
  const entitlementId = await proEntitlementId(env, project);

  let customer: any;
  try {
    // The app logs RevenueCat in with the Supabase user id.
    customer = await rcGet(`${project}/customers/${encodeURIComponent(userId)}`, env);
  } catch (error) {
    // A customer RevenueCat has never seen has no entitlements.
    if (error instanceof RevenueCatError && error.status === 404) return false;
    throw error;
  }

  const now = Date.now();
  let list = customer?.active_entitlements;
  for (let page = 0; list && page < MAX_PAGES; page++) {
    for (const e of list.items ?? []) {
      if (e?.entitlement_id !== entitlementId) continue;
      if (e.expires_at == null || Number(e.expires_at) > now) return true;
    }
    const next = nextPath(list.next_page);
    list = next ? await rcGet(next, env) : null;
  }
  return false;
}
