import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetAuthState } from '../src/auth';
import { resetCatalogState } from '../src/catalog';
import { resetPremiumState } from '../src/premium';
import { resetPopularityState } from '../src/recommend/popularity';
import { parseBody, wallClock } from '../src/recommend/route';
import { REASONS } from '../src/recommend/score';
import { itemIdFor } from '../src/recommend/signals';
import {
  json, mockFetch, rcCalls, recommendations, setupKeys, SUPABASE, token, type MockState,
} from './helpers';

let m: MockState;

beforeAll(setupKeys);
beforeEach(() => {
  resetAuthState();
  resetCatalogState();
  resetPremiumState();
  resetPopularityState();
  m = mockFetch();
  vi.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => vi.restoreAllMocks());

const MORNING = { localTime: '2026-11-02T08:00' };
const restCalls = (m: MockState) => m.requests.filter((r) => r.url.origin === SUPABASE && r.url.pathname.startsWith('/rest/v1/'));

type Body = { items: { id: string; reason: string }[]; rules: string; catalogVersion: number };

async function ok(res: Response): Promise<Body> {
  expect(res.status).toBe(200);
  return (await res.json()) as Body;
}

/** Serves rows per table; anything else is an empty list. */
function tables(rows: Record<string, unknown[]>) {
  return (url: URL) => json(rows[url.pathname.replace('/rest/v1/', '')] ?? []);
}

describe('POST /v1/recommendations: auth and input', () => {
  it('401 without a token', async () => {
    const res = await recommendations(undefined, {});
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'missing_token' });
  });

  it('401 for an expired token', async () => {
    const res = await recommendations(await token({ expiresIn: -60 }), {});
    expect(res.status).toBe(401);
  });

  it('429 when the per-user rate limit says no', async () => {
    const res = await recommendations(await token(), {}, {
      RATE_LIMITER: { limit: async () => ({ success: false }) } as unknown as RateLimit,
    });
    expect(res.status).toBe(429);
  });

  it.each([
    ['not JSON', '{nope'],
    ['an array', []],
    ['a mood out of range', { lastMood: 5 }],
    ['a fractional mood', { lastMood: 0.5 }],
    ['a bad mood time', { lastMood: 0, lastMoodAt: 'yesterday' }],
    ['a bad localTime', { localTime: '21:14' }],
    ['a bad course', { course: { id: 'calm2' } }],
    ['a negative course day', { course: { id: 'calm2', day: -1 } }],
    ['limit 0', { limit: 0 }],
    ['limit 21', { limit: 21 }],
    ['opensByKind with a negative count', { opensByKind: { sound: -1 } }],
    ['opensByKind as a list', { opensByKind: [1, 2] }],
    ['downloaded as a string', { downloaded: 'sound:Rainfall' }],
    ['offline as a string', { offline: 'no' }],
    ['a surface with spaces', { surface: 'home page' }],
  ])('400 for %s', async (_name, body) => {
    const res = await recommendations(await token(), body);
    expect(res.status).toBe(400);
    expect(((await res.json()) as any).error).toBe('bad_request');
  });

  it('accepts the full request from the design', async () => {
    const body = await ok(
      await recommendations(await token(), {
        surface: 'home',
        tz: 'Africa/Nairobi',
        localTime: '2026-11-02T21:14',
        catalogVersion: 42,
        locale: 'fr',
        lastMood: 3,
        lastMoodAt: '2026-11-02T18:00:00Z',
        opensByKind: { sound: 12, meditation: 3 },
        downloaded: ['meditation:Body scan'],
        offline: false,
        course: null,
      }),
    );
    expect(body.rules).toBe('v1');
    expect(body.catalogVersion).toBe(7);
    expect(body.items.length).toBeGreaterThan(0);
    for (const x of body.items) expect(typeof x.reason).toBe('string');
  });

  it('accepts an empty body and never caches the answer', async () => {
    const res = await recommendations(await token(), {});
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('private, no-store');
    expect((await ok(res)).items.length).toBeGreaterThan(0);
  });

  it('503 when the catalogue has never loaded', async () => {
    m.catalogUp = false;
    const res = await recommendations(await token(), {});
    expect(res.status).toBe(503);
  });
});

describe('POST /v1/recommendations: signals', () => {
  it("reads the three tables with the user's own token and the publishable key", async () => {
    const sub = crypto.randomUUID();
    const bearer = await token({ sub });
    await ok(await recommendations(bearer, MORNING));

    const calls = restCalls(m);
    expect(calls.map((c) => c.url.pathname).sort()).toEqual([
      '/rest/v1/practice_sessions',
      '/rest/v1/saved_items',
      '/rest/v1/session_feelings',
    ]);
    for (const { url, init } of calls) {
      const headers = new Headers(init?.headers);
      expect(headers.get('Authorization')).toBe(`Bearer ${bearer}`);
      expect(headers.get('apikey')).toBe('sb_publishable_test');
      expect(url.searchParams.get('user_id')).toBe(`eq.${sub}`);
      expect(init?.signal).toBeDefined();
    }
    const sessions = calls.find((c) => c.url.pathname.endsWith('practice_sessions'))!.url;
    expect(sessions.searchParams.get('completed_at')).toMatch(/^gte\.\d{4}-/);
  });

  it('uses feelings from Supabase for the reason', async () => {
    m.supabase = tables({
      session_feelings: [{ kind: 'meditation', slug: 'Body scan', feeling: 1, created_at: new Date().toISOString() }],
    });
    const body = await ok(await recommendations(await token({ comp: true }), { ...MORNING, limit: 20 }));
    expect(body.items.find((x) => x.id === 'breathing:Box breathing')?.reason).toBe(
      'Because you felt better after Body scan',
    );
  });

  it('ranks down what was finished in the last day, mapped from kind + title', async () => {
    const plain = await ok(await recommendations(await token({ comp: true }), { ...MORNING, limit: 20 }));
    m.supabase = tables({
      practice_sessions: [{ kind: 'meditation', slug: 'Urge surfing', completed_at: new Date().toISOString() }],
    });
    const after = await ok(await recommendations(await token({ comp: true }), { ...MORNING, limit: 20 }));
    const at = (b: Body) => b.items.findIndex((x) => x.id === 'recovery:Urge surfing');
    expect(at(after)).toBeGreaterThan(at(plain));
  });

  it('reads goals from the token', async () => {
    const body = await ok(await recommendations(await token({ goals: ['urges'] }), MORNING));
    expect(body.items[0]).toEqual({ id: 'recovery:Urge surfing', reason: "Because you're working on urges" });
  });

  it('uses the popularity snapshot', async () => {
    m.popularity = { format: 1, days: 30, items: [{ kind: 'prompt', slug: 'Worst case', users: 80 }] };
    const body = await ok(await recommendations(await token({ comp: true }), { ...MORNING, limit: 20 }));
    expect(body.items.find((x) => x.id === 'prompt:Worst case')?.reason).toBe(REASONS.popular);
  });

  it('loads popularity once an hour, not per request', async () => {
    m.popularity = { items: [] };
    await ok(await recommendations(await token(), MORNING));
    await ok(await recommendations(await token(), MORNING));
    expect(m.calls.filter((u) => u.endsWith('/stats/popularity.json'))).toHaveLength(1);
  });

  it('puts the course in progress first', async () => {
    const body = await ok(await recommendations(await token({ comp: true }), { ...MORNING, course: { id: 'calm2', day: 1 } }));
    expect(body.items[0]).toEqual({ id: 'meditation:Body scan', reason: 'Day 2 of 2 days to calm' });
  });
});

describe('POST /v1/recommendations: degraded', () => {
  it('still answers 200 when Supabase errors', async () => {
    m.supabase = () => json({ message: 'down' }, 500);
    expect((await ok(await recommendations(await token(), MORNING))).items).toHaveLength(6);
  });

  it('still answers 200 when Supabase is unreachable', async () => {
    m.supabase = () => {
      throw new TypeError('fetch failed');
    };
    expect((await ok(await recommendations(await token(), MORNING))).items).toHaveLength(6);
  });

  it('still answers 200 when the tables are not migrated yet (404)', async () => {
    m.supabase = () => json({ code: '42P01' }, 404);
    expect((await ok(await recommendations(await token(), MORNING))).items).toHaveLength(6);
  });

  it('still answers 200 when Supabase hangs: the timeout ends the wait', async () => {
    m.supabase = (_url, init) =>
      new Promise<Response>((_resolve, reject) => {
        const signal = init?.signal;
        if (!signal) return reject(new Error('no timeout signal passed'));
        signal.addEventListener('abort', () => reject(signal.reason));
      });
    expect((await ok(await recommendations(await token(), MORNING))).items).toHaveLength(6);
  }, 10_000);

  it('still answers 200 when the popularity file is missing or broken', async () => {
    m.popularity = null;
    await ok(await recommendations(await token(), MORNING));
    resetPopularityState();
    m.popularity = 'not an object';
    await ok(await recommendations(await token(), MORNING));
  });

  it('a RevenueCat failure means the free-user caps apply', async () => {
    m.revenueCat = () => json({}, 500);
    const body = await ok(await recommendations(await token(), { ...MORNING, limit: 6 }));
    const premium = ['meditation:Body scan', 'prompt:Worst case', 'meditation:Loving kindness'];
    expect(body.items.filter((x) => premium.includes(x.id)).length).toBeLessThanOrEqual(2);
  });
});

describe('POST /v1/recommendations: safety and premium', () => {
  const awful = () => ({ ...MORNING, lastMood: 0, lastMoodAt: new Date().toISOString(), limit: 20 });

  it('after an awful check-in, leads with grounding and leaves out deep and "good" items', async () => {
    const body = await ok(await recommendations(await token(), awful()));
    expect(body.items[0]).toEqual({ id: 'tool:Grounding: 5-4-3-2-1', reason: REASONS.lead });
    const ids = body.items.map((x) => x.id);
    expect(ids).not.toContain('prompt:Worst case');
    expect(ids).not.toContain('meditation:Loving kindness');
    expect(ids).not.toContain('meditation:Body scan');
  });

  it('a free user sees at most 2 premium items in the top 6', async () => {
    const body = await ok(await recommendations(await token({ goals: ['low', 'sleep', 'anxious'] }), MORNING));
    const premium = ['meditation:Body scan', 'prompt:Worst case', 'meditation:Loving kindness'];
    expect(body.items.slice(0, 6).filter((x) => premium.includes(x.id)).length).toBe(2);
  });

  it('a comp user is premium without asking RevenueCat', async () => {
    const body = await ok(await recommendations(await token({ comp: true }), { ...MORNING, limit: 20 }));
    const premium = ['meditation:Body scan', 'prompt:Worst case', 'meditation:Loving kindness'];
    expect(body.items.filter((x) => premium.includes(x.id)).length).toBe(3);
    expect(rcCalls(m)).toHaveLength(0);
  });
});

describe('helpers', () => {
  const has = (id: string) =>
    ['meditation:Body scan', 'recovery:Urge surfing', 'med-morning-reset'].includes(id);

  it('maps a session row to its item id', () => {
    expect(itemIdFor('meditation', 'Body scan', has)).toBe('meditation:Body scan');
    expect(itemIdFor('meditation', 'Urge surfing', has)).toBe('recovery:Urge surfing');
    expect(itemIdFor('meditation', 'med-morning-reset', has)).toBe('med-morning-reset');
    expect(itemIdFor('sound', 'Gone', has)).toBeNull();
  });

  it('works out the wall clock from the time zone', () => {
    const t = Date.parse('2026-11-02T18:30:00Z');
    expect(wallClock(t, 'Africa/Nairobi')).toBe('2026-11-02T21:30');
    expect(wallClock(t, 'Not/AZone')).toBe('2026-11-02T18:30');
    expect(wallClock(t, null)).toBe('2026-11-02T18:30');
  });

  it('trims seconds off localTime', () => {
    const parsed = parseBody({ localTime: '2026-11-02T21:14:59' });
    expect(typeof parsed !== 'string' && parsed.localTime).toBe('2026-11-02T21:14');
  });
});
