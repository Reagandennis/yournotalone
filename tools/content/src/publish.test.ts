import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { promisify } from 'node:util';
import { credentialsFromEnv, envs } from './config.ts';
import { type Item, check, load } from './content.ts';
import { execute, latestKey, mediaSources, type PlanOptions, plan, uploads } from './publisher.ts';
import { bundledFrom } from './bundle.ts';
import { snapshot } from './snapshot.ts';
import { MemoryStore, objectUrl, r2Store } from './store.ts';
import { inRepoOrMasters, mastersNotHere } from './testing.ts';

const base = check(load(), inRepoOrMasters);
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
  assert.deepEqual(Object.keys(snap), ['format', 'version', 'hash', 'builtAt', 'items', 'courses', 'backgrounds', 'media']);
});

test('the snapshot and latest.json say when they were made, outside the hash', async () => {
  const early = await plan({ ...opts(null), now: () => new Date('2026-11-04T19:29:01Z') });
  const late = await plan({ ...opts(null), now: () => new Date('2026-11-19T08:00:00Z') });
  assert.equal(dec(early.snapshot.body).builtAt, '2026-11-04T19:29:01.000Z');
  assert.equal(dec(early.latest.body).builtAt, '2026-11-04T19:29:01.000Z');
  assert.equal(dec(late.snapshot.body).builtAt, '2026-11-19T08:00:00.000Z');
  // The same content made later is the same catalogue.
  assert.equal(early.hash, late.hash);
});

test('version starts at 1 and counts up from the current latest', async () => {
  const empty = new MemoryStore();
  assert.equal((await plan(opts(empty))).version, 1);
  assert.equal((await plan(opts(empty))).previous, null);

  const store = new MemoryStore();
  await store.put(staging.bucket, staging.prefix + latestKey, enc(JSON.stringify({ version: 7, path: 'catalog/v7-0123456789abcdef.json', minApp: '1.1.0' })), { contentType: '', cacheControl: '' });
  const p = await plan({ ...opts(store), now: () => new Date('2026-11-19T08:00:00Z') });
  assert.equal(p.version, 8);
  assert.equal(p.previous, 7);
  assert.match(p.snapshot.key, new RegExp(`^staging/catalog/v8-${p.hash}\\.json$`));
  assert.deepEqual(dec(p.latest.body), {
    version: 8,
    path: `catalog/v8-${p.hash}.json`,
    minApp: '1.1.0',
    builtAt: '2026-11-19T08:00:00.000Z',
  });
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
  // Every media object was checked with HEAD before anything was written
  // (plus the public twin of each premium file, which must not exist).
  const mediaKeys = new Set(p.media.map((m) => m.key));
  assert.equal(store.calls.filter((c) => c.op === 'head' && mediaKeys.has(c.key)).length, p.media.length);
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
  assert.deepEqual(store.deletes(), []);
  // Only the check for public copies of premium media, which runs every time.
  const heads = store.calls.filter((c) => c.op === 'head');
  assert.ok(heads.length > 0);
  assert.ok(heads.every((c) => /^staging\/media\/[0-9a-f]{64}\.m4a$/.test(c.key)));

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

// The CLI checks the real files and transcodes them, so it needs every
// recording the content points at in Sounds/ (`npm run masters -- download
// --used`). Without them (a clean checkout, the tools CI job) it's skipped.
const notHere = mastersNotHere(load());
const cliSkip = notHere.length
  ? `needs ${notHere.join(', ')} in Sounds/ (in R2 only; npm run masters -- download --used)`
  : false;

test('the CLI dry run works without credentials; a real run refuses', { skip: cliSkip }, async () => {
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

/// The fixture's Rainfall, which starts free.
const sound = (items: Item[]) => items.find((i) => i.id === 'sound:Rainfall')!;

test('audio that was free and turns premium loses its public copy', async () => {
  const store = new MemoryStore();
  const items = fixture();
  assert.equal(sound(items).premium, false);
  const v1 = await plan(opts(store, items));
  await execute(v1, store);
  const ref1 = dec(v1.snapshot.body).media['sound:Rainfall'].audio;
  const publicKey = `yournotalone/staging/media/${ref1.sha256}.m4a`;
  assert.equal(ref1.access, 'public');
  assert.ok(store.objects.has(publicKey));
  assert.deepEqual(v1.deletes, []);

  sound(items).premium = true;
  store.calls = [];
  const v2 = await plan(opts(store, items));
  const ref2 = dec(v2.snapshot.body).media['sound:Rainfall'].audio;
  assert.equal(ref2.access, 'premium');
  assert.equal(ref2.sha256, ref1.sha256);
  assert.deepEqual(v2.deletes.map((d) => d.key), [`staging/media/${ref1.sha256}.m4a`]);
  const log: string[] = [];
  await execute(v2, store, (l) => log.push(l));
  assert.equal(store.objects.has(publicKey), false, 'public copy deleted');
  assert.ok(store.objects.has(`yournotalone/staging/private/media/${ref1.sha256}.m4a`));
  // Deleted only after latest.json points at the premium copy, and logged.
  const latestPut = store.calls.findIndex((c) => c.op === 'put' && c.key.endsWith(latestKey));
  assert.ok(latestPut >= 0, 'latest.json written');
  assert.ok(store.calls.findIndex((c) => c.op === 'delete') > latestPut);
  assert.ok(log.some((l) => /delete .*public copy of premium sound:Rainfall audio/.test(l)));
  // Nothing premium was ever put under the public prefix.
  assert.equal(store.puts().some((c) => c.key === `staging/media/${ref1.sha256}.m4a`), false);

  // Idempotent: the next publish is unchanged and finds nothing to delete.
  const v3 = await plan(opts(store, items));
  assert.equal(v3.unchanged, true);
  assert.deepEqual(v3.deletes, []);
});

test('a public copy left by an earlier publish is deleted even when nothing changed', async () => {
  const store = new MemoryStore();
  const items = fixture();
  sound(items).premium = true;
  const v1 = await plan(opts(store, items));
  await execute(v1, store);
  // As an older publisher left it: the same file also under media/.
  const ref = dec(v1.snapshot.body).media['sound:Rainfall'].audio;
  await store.put('yournotalone', `staging/media/${ref.sha256}.m4a`, enc('leak'), { contentType: 'audio/mp4', cacheControl: '' });

  const again = await plan(opts(store, items));
  assert.equal(again.unchanged, true);
  assert.equal(again.deletes.length, 1);
  store.calls = [];
  await execute(again, store);
  assert.deepEqual(store.puts(), []);
  assert.deepEqual(store.deletes().map((c) => c.key), [`staging/media/${ref.sha256}.m4a`]);
});

test('refuses to publish the same audio as both free and premium', async () => {
  const items = fixture();
  const storm = items.find((i) => i.id === 'sound:Distant storm')!;
  assert.equal(storm.premium, true);
  if (storm.body.type === 'sound' && sound(items).body.type === 'sound') {
    storm.body.audio = (sound(items).body as { audio: string }).audio;
  }
  await assert.rejects(plan(opts(null, items)), /free for sound:Rainfall audio and premium for sound:Distant storm audio/);
});

test('raising minApp or the snapshot format alone publishes a new version', async () => {
  const store = new MemoryStore();
  await execute(await plan(opts(store)), store);
  assert.equal((await plan(opts(store))).unchanged, true);

  const raised = await plan({ ...opts(store), minApp: '9.9.9' });
  assert.equal(raised.unchanged, false);
  assert.equal(raised.version, 2);
  assert.equal(dec(raised.latest.body).minApp, '9.9.9');
  await execute(raised, store);
  assert.equal((await plan({ ...opts(store), minApp: '9.9.9' })).unchanged, true);

  const format = await plan({ ...opts(store), minApp: '9.9.9', format: 2 });
  assert.equal(format.unchanged, false);
  assert.equal(dec(format.snapshot.body).format, 2);
});

test('media is uploaded with its sha256 as metadata', async () => {
  const store = new MemoryStore();
  const p = await plan(opts(store));
  await execute(p, store);
  for (const m of p.media) assert.equal(store.objects.get(`${m.bucket}/${m.key}`)!.metadata?.sha256, hex(m.body));
});

test('the R2 store reads metadata, sends it, and deletes', async () => {
  const seen: Request[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const req = new Request(input, init);
    seen.push(req);
    if (req.method === 'HEAD') return new Response(null, { status: 200, headers: { 'x-amz-meta-sha256': 'abc' } });
    return new Response(null, { status: req.method === 'DELETE' ? 204 : 200 });
  }) as typeof fetch;
  try {
    const store = r2Store('https://acct.r2.cloudflarestorage.com', { accessKeyId: 'a', secretAccessKey: 'b' });
    assert.deepEqual(await store.stat('bkt', 'private/masters/brown noise.wav'), { metadata: { sha256: 'abc' } });
    await store.put('bkt', 'k', enc('x'), { contentType: 'audio/wav', cacheControl: 'no-store', metadata: { sha256: 'def' } });
    await store.delete('bkt', 'media/x.m4a');
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal(seen[0].url, 'https://acct.r2.cloudflarestorage.com/bkt/private/masters/brown%20noise.wav');
  assert.equal(seen[1].headers.get('x-amz-meta-sha256'), 'def');
  assert.match(seen[1].headers.get('authorization')!, /x-amz-meta-sha256/);
  assert.equal(seen[2].method, 'DELETE');
  assert.equal(seen[2].url, 'https://acct.r2.cloudflarestorage.com/bkt/media/x.m4a');
});

test('the bundled copy is the published snapshot as version 0', async () => {
  const p = await plan({ ...opts(null), env: envs.production, now: () => new Date('2026-11-19T08:00:00Z') });
  const published = dec(p.snapshot.body);
  const bundled = bundledFrom(published, p.snapshot.key);
  // Exactly what `npm run build` would write from the same media and time.
  const built = snapshot({ ...base, items: fixture() }, 0, published.media, published.builtAt);
  assert.equal(JSON.stringify(bundled), JSON.stringify(built));
  assert.equal(bundled.hash, p.hash);

  const tampered = structuredClone(published);
  tampered.media['sound:Rainfall'].audio.access = 'premium';
  assert.throws(() => bundledFrom(tampered, p.snapshot.key), /doesn't match its hash/);
  assert.throws(() => bundledFrom(published, 'catalog/latest.json'), /isn't a catalogue snapshot path/);
});
