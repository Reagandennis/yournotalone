// npm run masters -- upload|download|check
//
// The original recordings (Sounds/ at the repo root) live in R2 under
// private/masters/, not in git (docs/backend-design.md §12, decision 4).
// content/masters.json lists each one with its size and sha256, so the
// folder can be put back on any machine and checked byte for byte.
//
//   upload    hashes Sounds/, uploads what R2 doesn't have, rewrites the list
//   download  fetches every listed file into Sounds/ and checks its hash;
//             with names after it, only those (the content workflow
//             fetches just the recordings items point at)
//   check     compares Sounds/ with the list, with no network
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import { credentialsFromEnv, envs, s3Endpoint } from './config.ts';
import { repoRoot } from './content.ts';
import { r2Store, type Store } from './store.ts';

export const mastersDir = join(repoRoot, 'Sounds');
export const manifestPath = join(repoRoot, 'content', 'masters.json');
export const mastersPrefix = 'private/masters/';
const bucket = envs.production.bucket;

export type Master = { name: string; key: string; bytes: number; sha256: string };

const types: Record<string, string> = {
  '.wav': 'audio/wav',
  '.aif': 'audio/aiff',
  '.aiff': 'audio/aiff',
  '.flac': 'audio/flac',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
};

const sha256 = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');

export function readManifest(path = manifestPath): Master[] {
  return existsSync(path) ? (JSON.parse(readFileSync(path, 'utf8')) as Master[]) : [];
}

/// What's in [dir] now, sorted by name. Hidden files are skipped.
export function scan(dir = mastersDir): Master[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((n) => !n.startsWith('.') && statSync(join(dir, n)).isFile())
    .sort()
    .map((name) => {
      const body = readFileSync(join(dir, name));
      return { name, key: mastersPrefix + name, bytes: body.length, sha256: sha256(body) };
    });
}

/// Uploads each file R2 doesn't already have. Returns the new list.
export async function upload(store: Store, dir = mastersDir, log = console.log): Promise<Master[]> {
  const found = scan(dir);
  for (const m of found) {
    if (await store.head(bucket, m.key)) {
      log(`  have  ${m.key}`);
      continue;
    }
    log(`  put   ${m.key} (${(m.bytes / 1e6).toFixed(1)} MB)`);
    await store.put(bucket, m.key, readFileSync(join(dir, m.name)), {
      contentType: types[extname(m.name).toLowerCase()] ?? 'application/octet-stream',
      cacheControl: 'private, no-store',
    });
  }
  return found;
}

/// Fetches every listed file that's missing or different. Throws on a
/// file whose bytes don't match the list.
export async function download(store: Store, list: Master[], dir = mastersDir, log = console.log) {
  mkdirSync(dir, { recursive: true });
  const local = new Map(scan(dir).map((m) => [m.name, m.sha256]));
  for (const m of list) {
    if (local.get(m.name) === m.sha256) continue;
    log(`  get   ${m.key}`);
    const body = await store.get(bucket, m.key);
    if (!body) throw new Error(`${m.key} isn't in R2`);
    if (sha256(body) !== m.sha256) throw new Error(`${m.key} doesn't match its sha256`);
    writeFileSync(join(dir, m.name), body);
  }
}

/// Names that are missing, changed, or not listed.
export function differences(list: Master[], found: Master[]): string[] {
  const now = new Map(found.map((m) => [m.name, m]));
  const out: string[] = [];
  for (const m of list) {
    const f = now.get(m.name);
    if (!f) out.push(`missing  ${m.name}`);
    else if (f.sha256 !== m.sha256) out.push(`changed  ${m.name}`);
    now.delete(m.name);
  }
  for (const name of now.keys()) out.push(`unlisted ${name}`);
  return out;
}

if (import.meta.main) {
  const cmd = process.argv[2];
  if (cmd === 'check') {
    const diff = differences(readManifest(), scan());
    console.log(diff.length ? diff.join('\n') : 'Sounds/ matches content/masters.json.');
    process.exit(diff.length ? 1 : 0);
  } else if (cmd === 'upload' || cmd === 'download') {
    const store = r2Store(s3Endpoint, credentialsFromEnv());
    if (cmd === 'upload') {
      const list = await upload(store);
      writeFileSync(manifestPath, `${JSON.stringify(list, null, 2)}\n`);
      console.log(`${list.length} master(s) in R2; wrote content/masters.json.`);
    } else {
      const names = new Set(process.argv.slice(3));
      const list = readManifest();
      const unknown = [...names].filter((n) => !list.some((m) => m.name === n));
      if (unknown.length) {
        console.error(`Not in content/masters.json: ${unknown.join(', ')}`);
        process.exit(1);
      }
      await download(store, names.size ? list.filter((m) => names.has(m.name)) : list);
      console.log('Sounds/ matches content/masters.json.');
    }
  } else {
    console.error('Usage: npm run masters -- upload|download [name…]|check');
    process.exit(1);
  }
}
