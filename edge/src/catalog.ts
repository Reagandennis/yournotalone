// The published catalogue (design §4), held in module memory and refreshed
// at most once every 60 s. Contract shared with tools/content:
//
//   GET {PUBLIC_BASE_URL}/catalog/latest.json
//     -> {"version": N, "path": "catalog/v{N}-{hash}.json", "minApp": "x.y.z"}
//   GET {PUBLIC_BASE_URL}/{path}
//     -> {format, version, hash, items[{id, premium, …}], courses[], media{…}}
//
// The Worker keeps ids, premium flags and media refs for signing, and the
// tags, titles and courses that recommendations score with.

import { logError } from './log';
import type { ScoreCatalog, ScoreCourse, ScoreItem } from './recommend/score';

export type Access = 'public' | 'premium';
export type MediaSlot = 'audio' | 'narration';
export const MEDIA_SLOTS: readonly MediaSlot[] = ['audio', 'narration'];

export interface MediaRef {
  key: string;
  sha256: string;
  bytes: number;
  access: Access;
}

export interface CatalogItem extends ScoreItem {
  media: Partial<Record<MediaSlot, MediaRef>>;
}

export interface Catalog {
  version: number;
  path: string;
  items: Map<string, CatalogItem>;
  /** What the scorer reads, built once per snapshot. */
  scoring: ScoreCatalog;
}

const REFRESH_MS = 60_000;
const FETCH_TIMEOUT_MS = 5_000;

interface State {
  baseUrl: string;
  catalog: Catalog | null;
  checkedAt: number;
  inflight: Promise<void> | null;
}

let state: State | null = null;

/** Test hook: drop the in-memory catalogue. */
export function resetCatalogState(): void {
  state = null;
}

/** The catalogue currently in memory, without triggering a refresh. */
export function currentCatalog(): Catalog | null {
  return state?.catalog ?? null;
}

/**
 * Returns the catalogue, refreshing it if the last check is older than 60 s.
 * A failed refresh keeps serving the previous copy; returns null only if no
 * catalogue has ever loaded.
 */
export async function getCatalog(publicBaseUrl: string, now = Date.now()): Promise<Catalog | null> {
  const baseUrl = publicBaseUrl.replace(/\/+$/, '');
  if (!state || state.baseUrl !== baseUrl) {
    state = { baseUrl, catalog: null, checkedAt: 0, inflight: null };
  }
  const s = state;
  if (now - s.checkedAt >= REFRESH_MS) {
    // Concurrent requests in one isolate share a single refresh.
    s.inflight ??= refresh(s).finally(() => {
      s.checkedAt = Date.now();
      s.inflight = null;
    });
    await s.inflight;
  }
  return s.catalog;
}

async function refresh(s: State): Promise<void> {
  try {
    const pointer = await fetchJson(`${s.baseUrl}/catalog/latest.json`);
    const version = pointer?.version;
    const path = pointer?.path;
    if (!Number.isInteger(version) || typeof path !== 'string' || !/^catalog\/[A-Za-z0-9._-]+\.json$/.test(path)) {
      throw new Error('latest.json is malformed');
    }
    if (s.catalog && s.catalog.version === version && s.catalog.path === path) return;

    const snapshot = await fetchJson(`${s.baseUrl}/${path}`);
    s.catalog = parseSnapshot(snapshot, version, path);
  } catch (error) {
    logError('catalog_refresh_failed', error, { hasCatalog: s.catalog !== null });
  }
}

async function fetchJson(url: string): Promise<any> {
  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`GET ${url} -> ${response.status}`);
  return response.json();
}

const KEY_RE = /^(private\/)?media\/[A-Za-z0-9._-]+$/;

function parseRef(raw: any): MediaRef | null {
  if (!raw || typeof raw !== 'object') return null;
  const { key, sha256, bytes, access } = raw;
  if (typeof key !== 'string' || !KEY_RE.test(key)) return null;
  if (typeof sha256 !== 'string' || typeof bytes !== 'number') return null;
  if (access !== 'public' && access !== 'premium') return null;
  return { key, sha256, bytes, access };
}

export function parseSnapshot(raw: any, version: number, path: string): Catalog {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.items)) {
    throw new Error('snapshot has no items[]');
  }
  const media = raw.media && typeof raw.media === 'object' ? raw.media : {};
  const items = new Map<string, CatalogItem>();
  for (const it of raw.items) {
    if (!it || typeof it.id !== 'string') continue;
    const refs: CatalogItem['media'] = {};
    for (const slot of MEDIA_SLOTS) {
      const ref = parseRef(media[it.id]?.[slot]);
      if (ref) refs[slot] = ref;
    }
    const tags = it.tags && typeof it.tags === 'object' ? it.tags : {};
    items.set(it.id, {
      id: it.id,
      kind: typeof it.kind === 'string' ? it.kind : '',
      title: str(it.text?.en?.title) ?? it.id,
      order: Number.isFinite(it.order) ? it.order : 0,
      premium: it.premium === true,
      addedOn: str(it.addedOn),
      needs: strings(tags.needs),
      dayParts: strings(tags.dayParts),
      intensity: str(tags.intensity),
      calmingSafe: tags.calmingSafe === true,
      support: tags.support === true,
      media: refs,
    });
  }
  const courses: ScoreCourse[] = [];
  for (const c of Array.isArray(raw.courses) ? raw.courses : []) {
    if (!c || typeof c.id !== 'string') continue;
    courses.push({ id: c.id, title: str(c.text?.en?.title) ?? c.id, days: strings(c.days) });
  }
  return { version, path, items, scoring: { items: [...items.values()], courses } };
}

const str = (x: unknown): string | null => (typeof x === 'string' ? x : null);
const strings = (x: unknown): string[] => (Array.isArray(x) ? x.filter((v) => typeof v === 'string') : []);
