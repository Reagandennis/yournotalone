import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { promisify } from 'node:util';
import { credentialsFromEnv, envs } from './config.ts';
import { type Item, check, load } from './content.ts';
import { execute, latestKey, mediaSources, type PlanOptions, plan, uploads } from './publisher.ts';
import { MemoryStore, objectUrl, r2Store } from './store.ts';

const base = check(load());
const staging = envs.staging;
const hex = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');
const enc = (s: string) => new TextEncoder().encode(s);
const dec = (b: Uint8Array) => JSON.parse(new TextDecoder().decode(b));

/// The repo's items, with Rainfall made free and Body scan given narration,
/// so every case shows up.
function fixture(): Item[] {
  return base.items.map((i) => {
    const c = structuredClone(i);
    if (c.id === 'sound:Rainfall') c.premium = false;
    if (c.id === 'meditation:Body scan' && c.body.type === 'meditation') {
      c.body.narration = 'masters/body_scan.wav';
    }
    return c;
  });
}

/// Stands in for ffmpeg: the "encoded" file is just its source path.
const fakePrepare: PlanOptions['prepare'] = async (src) => ({ bytes: enc(`audio:${src.path}`), note: 'fake' });

const opts = (store: MemoryStore | null, items = fixture()): PlanOptions => ({
  items,
  courses: base.courses,
  backgrounds: base.backgrounds,
  env: staging,
  minApp: '1.1.0',
  store,
  prepare: fakePrepare,
});

test('media keys come from the content', async () => {
  const a = await plan(opts(null));
  const b = await plan(opts(null));
  assert.deepEqual(
    a.media.map((m) => m.key),
    b.media.map((m) => m.key),
  );
  assert.equal(a.hash, b.hash);
  const rain = a.media.find((m) => m.label.startsWith('sound:Rainfall'))!;
  assert.equal(rain.key, `staging/media/${hex(enc('audio:assets/sounds/rainfall.m4a'))}.m4a`);
  assert.equal(rain.contentType, 'audio/mp4');
  assert.equal(rain.cacheControl, 'public, max-age=31536000, immutable');

  // Different bytes, different key and a different catalogue hash.
  const c = await plan({ ...opts(null), prepare: async (s) => ({ bytes: enc(`v2:${s.path}`), note: '' }) });
  assert.notEqual(c.media[0].key, a.media[0].key);
  assert.notEqual(c.hash, a.hash);
});

test('premium media goes under private/, free media and the catalogue are public', async () => {
  const p = await plan(opts(null));
  const snap = dec(p.snapshot.body);
  const rain = p.media.find((m) => m.label.startsWith('sound:Rainfall'))!;
  const storm = p.media.find((m) => m.label.startsWith('sound:Distant storm'))!;
  assert.ok(p.media.every((m) => m.bucket === 'yournotalone'));
  assert.match(rain.key, /^staging\/media\/[0-9a-f]{64}\.m4a$/);
  assert.equal(snap.media['sound:Rainfall'].audio.access, 'public');
  assert.match(storm.key, /^staging\/private\/media\/[0-9a-f]{64}\.m4a$/);
  assert.equal(snap.media['sound:Distant storm'].audio.access, 'premium');
  // Catalogue keys are relative to the environment.
  assert.equal(snap.media['sound:Distant storm'].audio.key, storm.key.slice('staging/'.length));
  assert.match(p.snapshot.key, /^staging\/catalog\//);
  assert.equal(p.latest.key, 'staging/catalog/latest.json');
  assert.match(dec(p.latest.body).path, /^catalog\/v1-/);

  const prod = await plan({ ...opts(null), env: envs.production });
  assert.ok(prod.media.every((m) => /^(private\/)?media\//.test(m.key)));
  assert.equal(prod.latest.key, 'catalog/latest.json');
});

test('the media map has one entry per item with media, in the agreed shape', async () => {
  const p = await plan(opts(null));
  const snap = dec(p.snapshot.body);
  const withMedia = mediaSources(fixture()).map((s) => s.itemId);
  assert.deepEqual(Object.keys(snap.media).sort(), [...new Set(withMedia)].sort());
  for (const entry of Object.values<Record<string, Record<string, unknown>>>(snap.media)) {
    for (const [field, ref] of Object.entries(entry)) {
      assert.ok(field === 'audio' || field === 'narration');
      assert.deepEqual(Object.keys(ref).sort(), ['access', 'bytes', 'key', 'sha256']);
      assert.equal(ref.key, `${ref.access === 'premium' ? 'private/' : ''}media/${ref.sha256}.m4a`);
      assert.equal(typeof ref.bytes, 'number');
    }
  }
  const scan = snap.media['meditation:Body scan'];
  assert.deepEqual(Object.keys(scan), ['narration']);
  assert.equal(scan.narration.access, 'premium');
  assert.deepEqual(Object.keys(snap.media['sound:Rainfall']), ['audio']);
  // Meditations without narration have no entry.
  assert.equal('meditation:Loving kindness' in snap.media, false);
  // The rest of the snapshot is what build writes, plus media.
  assert.deepEqual(Object.keys(snap), ['format', 'version', 'hash', 'items', 'courses', 'backgrounds', 'media']);
});

test('version starts at 1 and counts up from the current latest', async () => {
  const empty = new MemoryStore();
  assert.equal((await plan(opts(empty))).version, 1);
  assert.equal((await plan(opts(empty))).previous, null);

  const store = new MemoryStore();
  await store.put(staging.bucket, staging.prefix + latestKey, enc(JSON.stringify({ version: 7, path: 'catalog/v7-0123456789abcdef.json', minApp: '1.1.0' })), { contentType: '', cacheControl: '' });
  const p = await plan(opts(store));
  assert.equal(p.version, 8);
  assert.equal(p.previous, 7);
  assert.match(p.snapshot.key, new RegExp(`^staging/catalog/v8-${p.hash}\\.json$`));
  assert.deepEqual(dec(p.latest.body), { version: 8, path: `catalog/v8-${p.hash}.json`, minApp: '1.1.0' });
  assert.equal(dec(p.snapshot.body).version, 8);
});

test('uploads media first, then the snapshot, and latest.json last', async () => {
  const store = new MemoryStore();
  const p = await plan(opts(store));
  await execute(p, store);
  const puts = store.puts();
  assert.equal(puts.length, p.media.length + 2);
  assert.ok(puts.slice(0, -2).every((c) => /^staging\/(private\/)?media\//.test(c.key)));
  assert.equal(puts.at(-2)!.key, p.snapshot.key);
  assert.equal(puts.at(-1)!.key, 'staging/catalog/latest.json');
  const latest = store.objects.get(`yournotalone/staging/${latestKey}`)!;
  assert.equal(latest.cacheControl, 'public, max-age=60');
  assert.equal(latest.contentType, 'application/json');
  const snap = store.objects.get(`yournotalone/${p.snapshot.key}`)!;
  assert.equal(snap.cacheControl, 'public, max-age=31536000, immutable');
});

test('skips media the bucket already has', async () => {
  const store = new MemoryStore();
  const first = await plan(opts(store));
  const rain = first.media.find((m) => m.label.startsWith('sound:Rainfall'))!;
  await store.put(rain.bucket, rain.key, rain.body, { contentType: 'audio/mp4', cacheControl: '' });
  store.calls = [];

  const p = await plan(opts(store));
  assert.equal(p.media.find((m) => m.key === rain.key)!.exists, true);
  assert.ok(p.media.filter((m) => m.key !== rain.key).every((m) => m.exists === false));
  // Every media object was checked with HEAD before anything was written.
  assert.equal(store.calls.filter((c) => c.op === 'head').length, p.media.length);
  await execute(p, store);
  assert.equal(store.puts().some((c) => c.key === rain.key), false);
  assert.equal(store.puts().length, p.media.length - 1 + 2);
});

test('uploads nothing when the catalogue hash is unchanged', async () => {
  const store = new MemoryStore();
  await execute(await plan(opts(store)), store);
  store.calls = [];

  const again = await plan(opts(store));
  assert.equal(again.unchanged, true);
  assert.deepEqual(uploads(again), []);
  await execute(again, store);
  assert.deepEqual(store.puts(), []);
  assert.equal(store.calls.filter((c) => c.op === 'head').length, 0);

  // Changing one item's text does publish v2.
  const edited = fixture().map((i) => (i.id === 'sound:Rainfall' ? { ...i, order: 251 } : i));
  const next = await plan(opts(store, edited));
  assert.equal(next.unchanged, false);
  assert.equal(next.version, 2);
  // Media didn't change, so only the two catalogue files go up.
  assert.deepEqual(uploads(next).map((o) => o.key), [next.snapshot.key, staging.prefix + latestKey]);
});

test('drafts are not published, and neither is their media', async () => {
  const items = fixture().map((i) => (i.id === 'sound:Rainfall' ? { ...i, status: 'draft' as const } : i));
  const p = await plan(opts(null, items));
  assert.equal('sound:Rainfall' in dec(p.snapshot.body).media, false);
  assert.equal(p.media.some((m) => m.label.includes('sound:Rainfall')), false);
});

test('a dry run reads nothing, so it needs no store', async () => {
  const p = await plan(opts(null));
  assert.equal(p.previous, undefined);
  assert.equal(p.version, 1);
  assert.ok(p.media.every((m) => m.exists === undefined));
});

test('credentials are required for a real publish, with a clear error', () => {
  assert.throws(() => credentialsFromEnv({}), /R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY are not set/);
  assert.throws(() => credentialsFromEnv({ R2_ACCESS_KEY_ID: 'x' }), /R2_SECRET_ACCESS_KEY is not set/);
  assert.deepEqual(credentialsFromEnv({ R2_ACCESS_KEY_ID: 'a', R2_SECRET_ACCESS_KEY: 'b' }), {
    accessKeyId: 'a',
    secretAccessKey: 'b',
  });
});

const run = promisify(execFile);
const cli = (args: string[]) => {
  const env = { ...process.env };
  delete env.R2_ACCESS_KEY_ID;
  delete env.R2_SECRET_ACCESS_KEY;
  return run(process.execPath, ['src/publish.ts', ...args], {
    cwd: new URL('..', import.meta.url),
    env,
  });
};

test('the CLI dry run works without credentials; a real run refuses', async () => {
  const { stdout } = await cli(['--env', 'staging', '--dry-run']);
  assert.match(stdout, /Publish to staging \(dry run\): v1/);
  assert.match(stdout, /catalog\/latest\.json/);
  await assert.rejects(cli(['--env', 'staging']), (e: { code: number; stderr: string }) => {
    assert.equal(e.code, 1);
    assert.match(e.stderr, /R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY are not set/);
    return true;
  });
  await assert.rejects(cli(['--env', 'prod']), /Usage/);
});

test('the R2 store signs path-style S3 requests', async () => {
  const seen: Request[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const req = new Request(input, init);
    seen.push(req);
    return new Response(null, { status: req.method === 'HEAD' ? 404 : 200 });
  }) as typeof fetch;
  try {
    const store = r2Store('https://acct.r2.cloudflarestorage.com', { accessKeyId: 'a', secretAccessKey: 'b' });
    assert.equal(await store.head('bkt', 'media/x.m4a'), false);
    await store.put('bkt', 'catalog/latest.json', enc('{}'), {
      contentType: 'application/json',
      cacheControl: 'public, max-age=60',
    });
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal(seen[0].method, 'HEAD');
  assert.equal(seen[0].url, 'https://acct.r2.cloudflarestorage.com/bkt/media/x.m4a');
  assert.equal(seen[1].method, 'PUT');
  assert.equal(seen[1].headers.get('cache-control'), 'public, max-age=60');
  assert.equal(seen[1].headers.get('content-type'), 'application/json');
  assert.match(seen[1].headers.get('authorization')!, /^AWS4-HMAC-SHA256 Credential=a\/\d{8}\/auto\/s3\//);
  assert.equal(objectUrl('https://e', 'b', 'catalog/v1 x.json'), 'https://e/b/catalog/v1%20x.json');
});
