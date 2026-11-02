import { env } from 'cloudflare:workers';
import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { exportJWK, generateKeyPair, SignJWT, type CryptoKey, type JWK } from 'jose';
import { vi } from 'vitest';
import worker from '../src/index';
import type { Env } from '../src/env';

export const testEnv = env as unknown as Env;
export const SUPABASE = 'https://test-project.supabase.co';
export const CDN = 'https://cdn.test';
export const RC = 'https://api.revenuecat.com/v2';

// ---------------------------------------------------------------- keys
let goodKey: CryptoKey;
let otherKey: CryptoKey;
let jwks: { keys: JWK[] };

export async function setupKeys() {
  if (goodKey) return;
  const good = await generateKeyPair('ES256', { extractable: true });
  const other = await generateKeyPair('ES256', { extractable: true });
  goodKey = good.privateKey;
  otherKey = other.privateKey;
  const pub = await exportJWK(good.publicKey);
  jwks = { keys: [{ ...pub, kid: 'test-kid', alg: 'ES256', use: 'sig' }] };
}

export interface TokenOptions {
  sub?: string;
  aud?: string;
  iss?: string;
  expiresIn?: number; // seconds from now; negative = already expired
  comp?: boolean;
  forged?: boolean; // signed by a key not in the JWKS (same kid)
}

export async function token(o: TokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claims: Record<string, unknown> = { role: 'authenticated' };
  if (o.comp !== undefined) claims.app_metadata = { provider: 'email', premium_comp: o.comp };
  return new SignJWT(claims)
    .setProtectedHeader({ alg: 'ES256', kid: 'test-kid', typ: 'JWT' })
    .setSubject(o.sub ?? crypto.randomUUID())
    .setIssuer(o.iss ?? `${SUPABASE}/auth/v1`)
    .setAudience(o.aud ?? 'authenticated')
    .setIssuedAt(now - 60)
    .setExpirationTime(now + (o.expiresIn ?? 3600))
    .sign(o.forged ? otherKey : goodKey);
}

// ------------------------------------------------------------- catalogue
const hex = (c: string) => c.repeat(64);
export const REFS = {
  rain: { key: `media/${hex('a')}.m4a`, sha256: hex('a'), bytes: 812345, access: 'public' },
  bodyScan: { key: `private/media/${hex('b')}.m4a`, sha256: hex('b'), bytes: 9_000_000, access: 'premium' },
  bodyScanBed: { key: `media/${hex('c')}.m4a`, sha256: hex('c'), bytes: 400_000, access: 'public' },
};

export const SNAPSHOT = {
  format: 1,
  version: 7,
  hash: 'deadbeefcafef00d',
  items: [
    { id: 'sound:Rainfall', kind: 'sound', premium: false },
    { id: 'meditation:Body scan', kind: 'meditation', premium: true },
    { id: 'breathing:Box breathing', kind: 'breathing', premium: false },
  ],
  courses: [],
  media: {
    'sound:Rainfall': { audio: REFS.rain },
    'meditation:Body scan': { narration: REFS.bodyScan, audio: REFS.bodyScanBed },
  },
};
export const LATEST = { version: 7, path: 'catalog/v7-deadbeefcafef00d.json', minApp: '1.2.0' };

// ---------------------------------------------------------------- fetch
export type RcHandler = (url: URL, init?: RequestInit) => Response | Promise<Response>;

export interface MockState {
  calls: string[];
  revenueCat: RcHandler;
  catalogUp: boolean;
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

export const activeCustomer = (entitlementId = 'entl_pro_test', expiresAt: number | null = Date.now() + 86_400_000) =>
  json({
    object: 'customer',
    id: 'x',
    active_entitlements: {
      object: 'list',
      items: [{ object: 'customer.active_entitlement', entitlement_id: entitlementId, expires_at: expiresAt }],
      next_page: null,
      url: '/v2/projects/proj_test/customers/x/active_entitlements',
    },
  });

export const inactiveCustomer = () =>
  json({
    object: 'customer',
    id: 'x',
    active_entitlements: { object: 'list', items: [], next_page: null, url: '' },
  });

export function mockFetch(): MockState {
  const state: MockState = { calls: [], revenueCat: () => inactiveCustomer(), catalogUp: true };
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    state.calls.push(url.toString());
    if (url.toString() === `${SUPABASE}/auth/v1/.well-known/jwks.json`) return json(jwks);
    if (url.origin === CDN) {
      if (!state.catalogUp) return new Response('down', { status: 503 });
      if (url.pathname === '/catalog/latest.json') return json(LATEST);
      if (url.pathname === `/${LATEST.path}`) return json(SNAPSHOT);
      return new Response('not found', { status: 404 });
    }
    if (url.origin === 'https://api.revenuecat.com') return state.revenueCat(url, init);
    throw new Error(`unexpected fetch ${url}`);
  });
  return state;
}

export const rcCalls = (m: MockState) => m.calls.filter((u) => u.startsWith(RC));

// ----------------------------------------------------------------- calls
export async function call(
  path: string,
  init: RequestInit & { bearer?: string } = {},
  envOverride: Partial<Env> = {},
): Promise<Response> {
  const headers = new Headers(init.headers);
  if (init.bearer) headers.set('Authorization', `Bearer ${init.bearer}`);
  const request = new Request(`https://api.test${path}`, { ...init, headers }) as Request<unknown, IncomingRequestCfProperties>;
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, { ...testEnv, ...envOverride }, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

export function sign(bearer: string | undefined, body: unknown, envOverride: Partial<Env> = {}) {
  return call(
    '/v1/media/sign',
    {
      method: 'POST',
      bearer,
      headers: { 'Content-Type': 'application/json' },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    },
    envOverride,
  );
}
