// npm run bundle [-- --env production|staging]
//
// Writes assets/catalog/bundled.json from the catalogue the environment
// (production by default) actually serves, not from a local build. Media
// keys are the sha256 of the encoded file, and another machine's ffmpeg
// can encode differently, so a bundled.json built locally can name files
// that were never uploaded. This copies the published snapshot instead:
// the same items, courses, backgrounds, media and hash, as version 0
// (which marks the bundled copy), keeping the published `builtAt`.
//
// With R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY set it reads the bucket
// directly (what the content workflow does, right after publishing);
// without them it reads the public custom domain, where latest.json can
// be up to a minute old.
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { parseArgs } from 'node:util';
import { credentialsFromEnv, envNames, envs, type EnvName, s3Endpoint } from './config.ts';
import { repoRoot } from './content.ts';
import { latestKey, readLatest } from './publisher.ts';
import { r2Store, type Store } from './store.ts';

/// The bundled copy of a published snapshot read from [path]
/// (catalog/v{N}-{hash}.json). Throws unless it is whole: the hash in the
/// path, the hash in the file and the hash of its contents all agree.
export function bundledFrom(published: Record<string, unknown>, path: string): Record<string, unknown> {
  const m = /^catalog\/v(\d+)-([0-9a-f]{16})\.json$/.exec(path);
  if (!m) throw new Error(`${path} isn't a catalogue snapshot path`);
  const { format, items, courses, backgrounds, media } = published;
  if (!Array.isArray(items) || !Array.isArray(courses) || !Array.isArray(backgrounds) || !media) {
    throw new Error(`${path} is missing items, courses, backgrounds or media`);
  }
  // The same object, in the same order, that snapshot() hashes (and, for
  // snapshots published before the format was hashed, without it).
  const digest = (x: unknown) => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
  const hash = digest({ format, items, courses, backgrounds, media });
  const legacy = digest({ items, courses, backgrounds, media });
  if (published.hash !== m[2] || (hash !== m[2] && legacy !== m[2])) {
    throw new Error(`${path} doesn't match its hash (file says ${published.hash}, contents ${hash})`);
  }
  if (published.version !== Number(m[1])) throw new Error(`${path} says it is version ${published.version}`);
  return { ...published, version: 0 };
}

async function fetchJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(`GET ${url}: HTTP ${res.status}`);
  return res.json();
}

if (import.meta.main) {
  const { values } = parseArgs({ options: { env: { type: 'string', default: 'production' } } });
  const name = values.env as EnvName;
  if (!envNames.includes(name)) {
    console.error(`Usage: npm run bundle -- [--env ${envNames.join('|')}]`);
    process.exit(1);
  }
  const env = envs[name];
  let store: Store | null = null;
  if (process.env.R2_ACCESS_KEY_ID && process.env.R2_SECRET_ACCESS_KEY) {
    store = r2Store(s3Endpoint, credentialsFromEnv());
  }
  let path: string;
  let published: Record<string, unknown>;
  if (store) {
    const latest = await readLatest(store, env);
    if (!latest) throw new Error(`${env.bucket}/${env.prefix}${latestKey} doesn't exist; publish first`);
    path = latest.path;
    const bytes = await store.get(env.bucket, env.prefix + path);
    if (!bytes) throw new Error(`${env.bucket}/${env.prefix}${path} doesn't exist`);
    published = JSON.parse(new TextDecoder().decode(bytes));
  } else {
    const latest = (await fetchJson(`${env.publicBase}/${latestKey}`)) as { path?: unknown };
    if (typeof latest.path !== 'string') throw new Error(`${env.publicBase}/${latestKey} has no path`);
    path = latest.path;
    published = (await fetchJson(`${env.publicBase}/${path}`)) as Record<string, unknown>;
  }
  const snap = bundledFrom(published, path);
  const out = join(repoRoot, 'assets/catalog/bundled.json');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(snap) + '\n');
  console.log(`Wrote assets/catalog/bundled.json from ${env.name}'s ${path} (hash ${snap.hash}).`);
}
