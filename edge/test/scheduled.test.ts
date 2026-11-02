import { createExecutionContext, createScheduledController, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import type { Env } from '../src/env';
import { json, mockFetch, SUPABASE, testEnv, type MockState } from './helpers';

const KEY = 'staging/stats/popularity.json';
const SCHEDULED = Date.parse('2026-11-03T03:00:00Z');

let m: MockState;
let rpcCalls: { url: URL; init?: RequestInit }[];

beforeEach(async () => {
  vi.spyOn(console, 'log').mockImplementation(() => {});
  m = mockFetch();
  rpcCalls = [];
  m.supabase = (url, init) => {
    rpcCalls.push({ url, init });
    return json([
      { kind: 'sound', slug: 'Rainfall', users: 42 },
      { kind: 'meditation', slug: 'Body scan', users: 10 },
      { kind: 'breathing', slug: 'Box breathing', users: 9 },
      { kind: 'meditation', slug: 'Urge surfing', users: 57 },
    ]);
  };
  await testEnv.CONTENT_BUCKET!.delete(KEY);
});
afterEach(() => vi.restoreAllMocks());

async function runCron(env: Partial<Env> = {}) {
  const ctx = createExecutionContext();
  await worker.scheduled(
    createScheduledController({ cron: '0 3 * * *', scheduledTime: SCHEDULED }),
    { ...testEnv, ...env },
    ctx,
  );
  await waitOnExecutionContext(ctx);
}

describe('cron: popularity snapshot', () => {
  it('calls content_popularity and writes stats/popularity.json under KEY_PREFIX', async () => {
    await runCron();

    expect(rpcCalls).toHaveLength(1);
    const { url, init } = rpcCalls[0];
    expect(url.toString()).toBe(`${SUPABASE}/rest/v1/rpc/content_popularity`);
    expect(init?.method).toBe('POST');
    expect(JSON.parse(String(init?.body))).toEqual({ days: 30 });

    const object = await testEnv.CONTENT_BUCKET!.get(KEY);
    expect(object).not.toBeNull();
    expect(object!.httpMetadata?.contentType).toBe('application/json');
    expect(object!.httpMetadata?.cacheControl).toBe('public, max-age=3600');
    expect(await object!.json()).toEqual({
      format: 1,
      generatedAt: '2026-11-03T03:00:00.000Z',
      days: 30,
      // Biggest first; anything under 10 people dropped.
      items: [
        { kind: 'meditation', slug: 'Urge surfing', users: 57 },
        { kind: 'sound', slug: 'Rainfall', users: 42 },
        { kind: 'meditation', slug: 'Body scan', users: 10 },
      ],
    });
  });

  it('sends a new-style secret key as apikey only', async () => {
    await runCron();
    const headers = new Headers(rpcCalls[0].init?.headers);
    expect(headers.get('apikey')).toBe('sb_secret_test');
    expect(headers.get('Authorization')).toBeNull();
  });

  it('sends a legacy service-role JWT as apikey and bearer', async () => {
    await runCron({ SUPABASE_SERVICE_ROLE_KEY: 'eyJlegacy.jwt.key' });
    const headers = new Headers(rpcCalls[0].init?.headers);
    expect(headers.get('apikey')).toBe('eyJlegacy.jwt.key');
    expect(headers.get('Authorization')).toBe('Bearer eyJlegacy.jwt.key');
  });

  it('writes at the bucket root in production', async () => {
    await runCron({ KEY_PREFIX: '' });
    expect(await testEnv.CONTENT_BUCKET!.get('stats/popularity.json')).not.toBeNull();
    await testEnv.CONTENT_BUCKET!.delete('stats/popularity.json');
  });

  it('fails the run and writes nothing when the RPC fails', async () => {
    m.supabase = () => json({ message: 'boom' }, 500);
    await expect(runCron()).rejects.toThrow(/content_popularity -> 500/);
    expect(await testEnv.CONTENT_BUCKET!.get(KEY)).toBeNull();
  });

  it('skips without the service key, and makes no request', async () => {
    await runCron({ SUPABASE_SERVICE_ROLE_KEY: undefined });
    expect(m.calls).toEqual([]);
    expect(await testEnv.CONTENT_BUCKET!.get(KEY)).toBeNull();
  });
});
