// The publish pipeline without the CLI around it: work out what to upload
// (plan), then upload it in a safe order (execute). See
// docs/backend-design.md §4 "Object keys" and "Published catalogue
// snapshot", and §8.
import type { Background, Course, Item } from './content.ts';
import { type EnvConfig, privatePrefix } from './config.ts';
import { type MediaMap, type MediaRef, snapshot } from './snapshot.ts';
import type { Store } from './store.ts';
import { type Prepared, type Role, sha256 } from './transcode.ts';

export const immutable = 'public, max-age=31536000, immutable';
export const latestCacheControl = 'public, max-age=60';
export const latestKey = 'catalog/latest.json';

export type MediaSource = {
  itemId: string;
  field: 'audio' | 'narration';
  /// Repo-relative path of the source file.
  path: string;
  role: Role;
  premium: boolean;
};

/// Every media file a published item points at.
export function mediaSources(items: Item[]): MediaSource[] {
  const out: MediaSource[] = [];
  for (const i of items) {
    if (i.status !== 'published') continue;
    const premium = i.premium;
    if (i.body.type === 'sound') {
      out.push({ itemId: i.id, field: 'audio', path: i.body.audio, role: 'ambient', premium });
    } else if (i.body.type === 'meditation' && i.body.narration) {
      out.push({ itemId: i.id, field: 'narration', path: i.body.narration, role: 'voice', premium });
    }
  }
  return out;
}

export type PrepareMedia = (src: MediaSource) => Promise<Prepared>;

export type PlannedObject = {
  bucket: string;
  key: string;
  body: Uint8Array;
  contentType: string;
  cacheControl: string;
  /// What it is, for the printed plan.
  label: string;
  /// Whether it's already in the bucket. Undefined when not checked (dry
  /// run) or not applicable (catalogue files are always written).
  exists?: boolean;
};

/// A public copy of premium media, to delete: media keys are content
/// hashes, so a file that was free once (media/<sha>.m4a) is the same file
/// as its premium copy (private/media/<sha>.m4a), and the catalogue prints
/// the sha256.
export type PlannedDelete = { bucket: string; key: string; label: string };

export type Plan = {
  env: EnvConfig;
  /// The version this publish would create.
  version: number;
  /// The current latest.json's version, null if there is none, undefined
  /// if it wasn't read (dry run).
  previous: number | null | undefined;
  hash: string;
  /// Same hash and minApp as the current latest: nothing to upload.
  unchanged: boolean;
  /// Public copies of premium media that are in the bucket and must go.
  /// Checked on every real publish, changed or not, so a leak left by an
  /// earlier publish is cleaned up too. Empty (unchecked) in a dry run.
  deletes: PlannedDelete[];
  media: PlannedObject[];
  snapshot: PlannedObject;
  latest: PlannedObject;
};

const json = (x: unknown) => new TextEncoder().encode(JSON.stringify(x));

/// Reads the target's latest.json: `{version, path}`, plus the snapshot hash
/// taken from the path.
export async function readLatest(store: Store, env: EnvConfig) {
  const bucket = env.bucket;
  const key = env.prefix + latestKey;
  const bytes = await store.get(bucket, key);
  if (!bytes) return null;
  const j = JSON.parse(new TextDecoder().decode(bytes));
  const m = typeof j.path === 'string' ? /^catalog\/v(\d+)-([0-9a-f]+)\.json$/.exec(j.path) : null;
  if (!Number.isInteger(j.version) || j.version < 1 || !m) {
    throw new Error(`${bucket}/${key} doesn't look right: ${JSON.stringify(j)}`);
  }
  return {
    version: j.version as number,
    path: j.path as string,
    hash: m[2],
    minApp: typeof j.minApp === 'string' ? (j.minApp as string) : null,
  };
}

export type PlanOptions = {
  items: Item[];
  courses: Course[];
  backgrounds: Background[];
  env: EnvConfig;
  minApp: string;
  /// null for a dry run: no reads, so nothing is checked against the bucket.
  store: Store | null;
  prepare: PrepareMedia;
  /// When this publish happens; the clock unless a test fixes it.
  now?: () => Date;
  /// The snapshot format; snapshotFormat unless a test changes it.
  format?: number;
};

export async function plan(o: PlanOptions): Promise<Plan> {
  const { env } = o;

  // 1. Media: prepare each file, key it by its own hash.
  const media: MediaMap = {};
  const objects = new Map<string, PlannedObject>();
  const sources = mediaSources(o.items).sort((a, b) =>
    a.itemId < b.itemId ? -1 : a.itemId > b.itemId ? 1 : a.field < b.field ? -1 : 1,
  );
  for (const src of sources) {
    const { bytes, note } = await o.prepare(src);
    const hex = sha256(bytes);
    const access = src.premium ? 'premium' : 'public';
    // Keys in the catalogue are relative to the environment's base URL.
    const key = `${src.premium ? privatePrefix : ''}media/${hex}.m4a`;
    const ref: MediaRef = { key, sha256: hex, bytes: bytes.length, access };
    (media[src.itemId] ??= {})[src.field] = ref;

    const bucket = env.bucket;
    const id = `${bucket}/${env.prefix}${ref.key}`;
    const label = `${src.itemId} ${src.field} (${note})`;
    const seen = objects.get(id);
    if (seen) seen.label += `; ${label}`;
    else {
      objects.set(id, {
        bucket,
        key: env.prefix + ref.key,
        body: bytes,
        contentType: 'audio/mp4',
        cacheControl: immutable,
        label,
      });
    }
  }

  // The same bytes can't be both free and premium: the free copy would be
  // the premium file, public. Refuse rather than publish that.
  const accessBySha = new Map<string, Map<string, string[]>>();
  for (const [itemId, refs] of Object.entries(media)) {
    for (const [field, ref] of Object.entries(refs)) {
      const byAccess = accessBySha.get(ref.sha256) ?? new Map<string, string[]>();
      accessBySha.set(ref.sha256, byAccess);
      byAccess.set(ref.access, [...(byAccess.get(ref.access) ?? []), `${itemId} ${field}`]);
    }
  }
  for (const [sha, byAccess] of accessBySha) {
    if (byAccess.size > 1) {
      throw new Error(
        `The same audio (sha256 ${sha}) is free for ${byAccess.get('public')!.join(', ')} ` +
          `and premium for ${byAccess.get('premium')!.join(', ')}. Its public copy would give the ` +
          'premium file away, so nothing was published. Make them all free or all premium, or use ' +
          'a different recording for one.',
      );
    }
  }
  const premiumShas = [...accessBySha].filter(([, a]) => a.has('premium')).map(([sha, a]) => ({
    sha,
    label: a.get('premium')!.join('; '),
  }));

  // 2. Version: one past the target's current latest.
  const latest = o.store ? await readLatest(o.store, env) : undefined;
  const previous = latest === undefined ? undefined : (latest?.version ?? null);
  const version = (latest?.version ?? 0) + 1;

  // 3. The snapshot, with the media map, stamped with when it was made.
  // latest.json carries the stamp too, so the app can skip a catalogue
  // older than the one it has without fetching it.
  const builtAt = (o.now?.() ?? new Date()).toISOString();
  const snap = snapshot(o, version, media, builtAt, o.format);
  const snapKey = `catalog/v${version}-${snap.hash}.json`;
  // minApp is only in latest.json, so it's compared on its own: raising it
  // with no content change still publishes.
  const unchanged = latest != null && latest.hash === snap.hash && latest.minApp === o.minApp;

  // 4. Which media the bucket already has.
  if (o.store && !unchanged) {
    for (const obj of objects.values()) obj.exists = await o.store.head(obj.bucket, obj.key);
  }

  // 5. Public copies of premium media (from when it was free).
  const deletes: PlannedDelete[] = [];
  if (o.store) {
    for (const { sha, label } of premiumShas) {
      const key = `${env.prefix}media/${sha}.m4a`;
      if (await o.store.head(env.bucket, key)) {
        deletes.push({ bucket: env.bucket, key, label: `public copy of premium ${label}` });
      }
    }
  }

  return {
    env,
    version,
    previous,
    hash: snap.hash,
    unchanged,
    deletes,
    media: [...objects.values()],
    snapshot: {
      bucket: env.bucket,
      key: env.prefix + snapKey,
      body: json(snap),
      contentType: 'application/json',
      cacheControl: immutable,
      label: `catalogue v${version}`,
    },
    latest: {
      bucket: env.bucket,
      key: env.prefix + latestKey,
      body: json({ version, path: snapKey, minApp: o.minApp, builtAt }),
      contentType: 'application/json',
      cacheControl: latestCacheControl,
      label: `pointer to v${version}`,
    },
  };
}

/// The objects to write, in order: new media, then the versioned
/// catalogue, then latest.json last, so nobody is ever pointed at a file
/// that isn't there yet. ([execute] then deletes [Plan.deletes].)
export function uploads(p: Plan): PlannedObject[] {
  if (p.unchanged) return [];
  return [...p.media.filter((m) => m.exists !== true), p.snapshot, p.latest];
}

export async function execute(
  p: Plan,
  store: Store,
  log: (msg: string) => void = () => {},
): Promise<PlannedObject[]> {
  const todo = uploads(p);
  for (const o of todo) {
    log(`  put ${o.bucket}/${o.key} (${size(o.body.length)})`);
    const hex = o.contentType === 'audio/mp4' ? sha256(o.body) : undefined;
    await store.put(o.bucket, o.key, o.body, {
      contentType: o.contentType,
      cacheControl: o.cacheControl,
      ...(hex ? { metadata: { sha256: hex } } : {}),
    });
  }
  // After latest.json, which no longer points at them. Idempotent: a
  // delete of an object that's gone is fine, and the next publish finds
  // nothing to delete.
  for (const d of p.deletes) {
    log(`  delete ${d.bucket}/${d.key} (${d.label})`);
    await store.delete(d.bucket, d.key);
  }
  return todo;
}

export function size(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / 1024 / 1024).toFixed(2)} MB`;
}

/// The plan as lines of text.
export function describe(p: Plan, dryRun: boolean): string[] {
  const lines: string[] = [];
  const from =
    p.previous === undefined
      ? "current latest.json not read in a dry run; assuming there is none"
      : p.previous === null
        ? 'no latest.json yet'
        : `current is v${p.previous}`;
  lines.push(`Publish to ${p.env.name}${dryRun ? ' (dry run)' : ''}: v${p.version}, hash ${p.hash} (${from})`);
  const deletes = p.deletes.map((d) => `  delete  ${d.bucket}/${d.key}  ${d.label}`);
  if (p.unchanged) {
    lines.push(`Nothing changed since v${p.previous} (same hash ${p.hash} and minApp). Nothing to upload.`);
    if (deletes.length) lines.push('Public copies of premium media to delete:', ...deletes);
    return lines;
  }
  const action = (o: PlannedObject) =>
    o.exists === true ? 'skip  ' : o.exists === false ? 'upload' : dryRun ? 'upload?' : 'upload';
  const row = (o: PlannedObject, a: string) =>
    `  ${a.padEnd(7)} ${size(o.body.length).padStart(9)}  ${o.bucket}/${o.key}  ${o.label}`;
  lines.push(`Media (${p.media.length}):`);
  for (const m of p.media) lines.push(row(m, action(m)));
  lines.push('Catalogue:');
  lines.push(row(p.snapshot, 'upload'));
  lines.push(row(p.latest, 'upload'));
  if (deletes.length) lines.push('Public copies of premium media to delete (after latest.json):', ...deletes);

  const todo = uploads(p);
  const bytes = todo.reduce((n, o) => n + o.body.length, 0);
  const skipped = p.media.filter((m) => m.exists === true).length;
  lines.push(
    `${todo.length} object(s) to upload, ${size(bytes)}; ${skipped} already there` +
      (dryRun ? ' (media existence not checked in a dry run, so "upload?")' : '') +
      '.',
  );
  return lines;
}
