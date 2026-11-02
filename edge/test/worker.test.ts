import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetAuthState } from '../src/auth';
import { resetCatalogState } from '../src/catalog';
import { resetPremiumState } from '../src/premium';
import {
  activeCustomer, call, CDN, inactiveCustomer, json, LATEST, mockFetch, rcCalls, REFS,
  setupKeys, sign, token, type MockState,
} from './helpers';

let m: MockState;

beforeAll(setupKeys);
beforeEach(() => {
  resetAuthState();
  resetCatalogState();
  resetPremiumState();
  m = mockFetch();
});
afterEach(() => vi.restoreAllMocks());

const BODY_SCAN = 'meditation:Body scan';
const RAIN = 'sound:Rainfall';

function amzExpires(url: string): number {
  return Number(new URL(url).searchParams.get('X-Amz-Expires'));
}

describe('auth', () => {
  const body = { items: [RAIN], purpose: 'stream' };

  it('401 without a token', async () => {
    const res = await sign(undefined, body);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'missing_token' });
  });

  it('401 with a non-bearer Authorization header', async () => {
    const res = await call('/v1/media/sign', { method: 'POST', headers: { Authorization: 'Basic abc' } });
    expect(res.status).toBe(401);
  });

  it('401 for an expired token', async () => {
    const res = await sign(await token({ expiresIn: -120 }), body);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'token_expired' });
  });

  it('401 for the wrong audience', async () => {
    const res = await sign(await token({ aud: 'anon' }), body);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'invalid_token' });
  });

  it('401 for the wrong issuer', async () => {
    const res = await sign(await token({ iss: 'https://evil.supabase.co/auth/v1' }), body);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'invalid_token' });
  });

  it('401 for a signature from another key', async () => {
    const res = await sign(await token({ forged: true }), body);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'invalid_token' });
  });

  it('401 for garbage', async () => {
    const res = await sign('not.a.jwt', body);
    expect(res.status).toBe(401);
  });

  it('accepts a valid token', async () => {
    const res = await sign(await token(), body);
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('application/json');
  });
});

describe('POST /v1/media/sign', () => {
  it('returns the public URL for a free item, with no premium check', async () => {
    const res = await sign(await token(), { items: [RAIN], purpose: 'stream' });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      urls: {
        [RAIN]: { audio: { url: `${CDN}/${REFS.rain.key}`, expires: null, sha256: REFS.rain.sha256, bytes: REFS.rain.bytes } },
      },
      missing: [],
    });
    expect(rcCalls(m)).toEqual([]);
  });

  it('signs a premium item for a comp user, 6 h for stream', async () => {
    const before = Date.now();
    const res = await sign(await token({ comp: true }), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(200);
    const out: any = await res.json();
    const narration = out.urls[BODY_SCAN].narration;
    expect(narration.url).toMatch(
      /^https:\/\/f7e65097ea4facdba994ee51d751705a\.r2\.cloudflarestorage\.com\/yournotalone\/staging\/private\/media\/b{64}\.m4a\?/,
    );
    expect(narration.url).toContain('X-Amz-Signature=');
    expect(amzExpires(narration.url)).toBe(6 * 3600);
    const expires = Date.parse(narration.expires);
    expect(expires - before).toBeGreaterThanOrEqual(6 * 3600 * 1000 - 2000);
    expect(expires - before).toBeLessThanOrEqual(6 * 3600 * 1000 + 2000);
    expect(narration.sha256).toBe(REFS.bodyScan.sha256);
    expect(narration.bytes).toBe(REFS.bodyScan.bytes);
    // The public bed on the same item stays a plain CDN URL.
    expect(out.urls[BODY_SCAN].audio).toEqual({
      url: `${CDN}/${REFS.bodyScanBed.key}`, expires: null, sha256: REFS.bodyScanBed.sha256, bytes: REFS.bodyScanBed.bytes,
    });
    // Comp users never hit RevenueCat.
    expect(rcCalls(m)).toEqual([]);
  });

  it('signs for 1 h when purpose is download', async () => {
    const before = Date.now();
    const res = await sign(await token({ comp: true }), { items: [BODY_SCAN], purpose: 'download' });
    const out: any = await res.json();
    const narration = out.urls[BODY_SCAN].narration;
    expect(narration.url).toContain('X-Amz-Signature=');
    expect(amzExpires(narration.url)).toBe(3600);
    expect(Date.parse(narration.expires) - before).toBeLessThanOrEqual(3600 * 1000 + 2000);
    expect(Date.parse(narration.expires) - before).toBeGreaterThanOrEqual(3600 * 1000 - 2000);
  });

  it('signs a premium item when RevenueCat says the entitlement is active', async () => {
    const sub = crypto.randomUUID();
    m.revenueCat = (url) => {
      expect(url.pathname).toBe(`/v2/projects/proj_test/customers/${sub}`);
      return activeCustomer();
    };
    const res = await sign(await token({ sub }), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(200);
    const out: any = await res.json();
    expect(out.urls[BODY_SCAN].narration.url).toContain('X-Amz-Signature=');
    expect(rcCalls(m)).toHaveLength(1);
  });

  it('sends the RevenueCat secret as a bearer token', async () => {
    let auth: string | null = null;
    m.revenueCat = (_url, init) => {
      auth = new Headers(init?.headers).get('Authorization');
      return activeCustomer();
    };
    await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(auth).toBe('Bearer sk_test');
  });

  it('403 when RevenueCat has no active pro entitlement', async () => {
    m.revenueCat = () => inactiveCustomer();
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'premium_required' });
  });

  it('403 when only some other entitlement is active', async () => {
    m.revenueCat = () => activeCustomer('entl_something_else');
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  });

  it('403 when the entitlement has already expired', async () => {
    m.revenueCat = () => activeCustomer('entl_pro_test', Date.now() - 1000);
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  });

  it('403 for the whole request when any item is premium (free items included)', async () => {
    const res = await sign(await token(), { items: [RAIN, BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  });

  it('403 for a customer RevenueCat has never seen (404)', async () => {
    m.revenueCat = () => json({ type: 'resource_missing' }, 404);
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  });

  it('fails closed on a RevenueCat 500', async () => {
    m.revenueCat = () => json({ error: 'boom' }, 500);
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  });

  it('fails closed when RevenueCat times out', async () => {
    // Never answers; only the Worker's own abort signal ends the request.
    m.revenueCat = (_url, init) =>
      new Promise<Response>((_resolve, reject) => {
        const signal = init?.signal;
        if (!signal) return reject(new Error('no timeout signal passed'));
        signal.addEventListener('abort', () => reject(signal.reason));
      });
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' });
    expect(res.status).toBe(403);
  }, 10_000);

  it('does not cache a RevenueCat failure', async () => {
    const sub = crypto.randomUUID();
    m.revenueCat = () => json({}, 500);
    expect((await sign(await token({ sub }), { items: [BODY_SCAN], purpose: 'stream' })).status).toBe(403);
    m.revenueCat = () => activeCustomer();
    expect((await sign(await token({ sub }), { items: [BODY_SCAN], purpose: 'stream' })).status).toBe(200);
  });

  it('caches the RevenueCat answer in caches.default (second call makes no fetch)', async () => {
    const sub = crypto.randomUUID();
    m.revenueCat = () => activeCustomer();
    expect((await sign(await token({ sub }), { items: [BODY_SCAN], purpose: 'stream' })).status).toBe(200);
    expect(rcCalls(m)).toHaveLength(1);

    // Drop the in-isolate copy so the answer must come from the Cache API.
    resetPremiumState();
    m.revenueCat = () => {
      throw new Error('RevenueCat should not be called');
    };
    expect((await sign(await token({ sub }), { items: [BODY_SCAN], purpose: 'stream' })).status).toBe(200);
    expect(rcCalls(m)).toHaveLength(1);
  });

  it('resolves the entitlement lookup key when PRO_ENTITLEMENT_ID is not set', async () => {
    m.revenueCat = (url) => {
      if (url.pathname === '/v2/projects/proj_test/entitlements') {
        return json({
          object: 'list',
          items: [
            { object: 'entitlement', id: 'entl_other', lookup_key: 'Other' },
            { object: 'entitlement', id: 'entl_resolved', lookup_key: 'Techgetafrica Pro' },
          ],
          next_page: null,
        });
      }
      return activeCustomer('entl_resolved');
    };
    const res = await sign(await token(), { items: [BODY_SCAN], purpose: 'stream' }, { PRO_ENTITLEMENT_ID: '' });
    expect(res.status).toBe(200);
  });

  it('puts unknown ids and items without media in missing', async () => {
    const res = await sign(await token(), {
      items: [RAIN, 'meditation:Does not exist', 'breathing:Box breathing'],
      purpose: 'download',
    });
    expect(res.status).toBe(200);
    const out: any = await res.json();
    expect(Object.keys(out.urls)).toEqual([RAIN]);
    expect(out.missing).toEqual(['meditation:Does not exist', 'breathing:Box breathing']);
  });

  it.each([
    ['not JSON', '{nope'],
    ['an array', [RAIN]],
    ['no items', { purpose: 'stream' }],
    ['empty items', { items: [], purpose: 'stream' }],
    ['non-string item', { items: [42], purpose: 'stream' }],
    ['empty string item', { items: [''], purpose: 'stream' }],
    ['bad purpose', { items: [RAIN], purpose: 'forever' }],
    ['missing purpose', { items: [RAIN] }],
  ])('400 for %s', async (_name, body) => {
    const res = await sign(await token(), body);
    expect(res.status).toBe(400);
    expect(((await res.json()) as any).error).toBe('bad_request');
  });

  it('400 for more than 50 items', async () => {
    const items = Array.from({ length: 51 }, (_, i) => `sound:Item ${i}`);
    const res = await sign(await token(), { items, purpose: 'stream' });
    expect(res.status).toBe(400);
  });

  it('accepts exactly 50 items', async () => {
    const items = Array.from({ length: 50 }, (_, i) => `sound:Item ${i}`);
    const res = await sign(await token(), { items, purpose: 'stream' });
    expect(res.status).toBe(200);
    expect(((await res.json()) as any).missing).toHaveLength(50);
  });

  it('503 when the catalogue has never loaded', async () => {
    m.catalogUp = false;
    const res = await sign(await token(), { items: [RAIN], purpose: 'stream' });
    expect(res.status).toBe(503);
  });
});

describe('catalogue cache', () => {
  it('loads once and reuses it for 60 s', async () => {
    const t = await token();
    await sign(t, { items: [RAIN], purpose: 'stream' });
    await sign(t, { items: [RAIN], purpose: 'stream' });
    expect(m.calls.filter((u) => u === `${CDN}/catalog/latest.json`)).toHaveLength(1);
    expect(m.calls.filter((u) => u === `${CDN}/${LATEST.path}`)).toHaveLength(1);
  });
});

describe('GET /healthz', () => {
  it('works without auth and reports the catalogue version', async () => {
    const res = await call('/healthz');
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, catalogVersion: 7 });
  });

  it('reports a null version when the catalogue is unreachable', async () => {
    m.catalogUp = false;
    const res = await call('/healthz');
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, catalogVersion: null });
  });
});

describe('misc', () => {
  it('404 JSON for unknown routes', async () => {
    const res = await call('/nope');
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: 'not_found' });
  });

  it('answers CORS preflight', async () => {
    const res = await call('/v1/media/sign', {
      method: 'OPTIONS',
      headers: { Origin: 'https://x.test', 'Access-Control-Request-Method': 'POST' },
    });
    expect(res.status).toBe(204);
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
  });
});
