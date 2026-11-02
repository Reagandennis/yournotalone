// The daily popularity snapshot (design §5, "Cron").
//
//   cron 03:00 UTC: POST {SUPABASE_URL}/rest/v1/rpc/content_popularity {"days": 30}
//     with the service-role key -> [{kind, slug, users}], users >= 10 only
//   -> R2 {KEY_PREFIX}stats/popularity.json, served at
//      {PUBLIC_BASE_URL}/stats/popularity.json:
//      {"format": 1, "generatedAt": "…", "days": 30,
//       "items": [{"kind": "sound", "slug": "Rainfall", "users": 42}, …]}
//
// Only aggregate counts, no user ids. Rows keep the kind and slug the
// tables store; recommendations map them to item ids against whichever
// catalogue is current.

import type { Env } from '../env';
import { logError, logInfo } from '../log';
import { itemIdFor } from './signals';

export const POPULARITY_KEY = 'stats/popularity.json';
export const POPULARITY_DAYS = 30;
/** Counts under this are dropped, here and in the SQL. */
export const MIN_USERS = 10;

const RPC_TIMEOUT_MS = 20_000;
const FETCH_TIMEOUT_MS = 2_000;
const REFRESH_MS = 60 * 60 * 1000;
const RETRY_MS = 5 * 60 * 1000;
const MAX_ROWS = 5_000;

export interface PopularityRow {
  kind: string;
  slug: string;
  users: number;
}

function cleanRows(raw: unknown): PopularityRow[] {
  if (!Array.isArray(raw)) throw new Error('expected an array of rows');
  const rows: PopularityRow[] = [];
  for (const r of raw.slice(0, MAX_ROWS)) {
    const users = Number(r?.users);
    if (typeof r?.kind !== 'string' || typeof r?.slug !== 'string') continue;
    if (!Number.isFinite(users) || users < MIN_USERS) continue;
    rows.push({ kind: r.kind, slug: r.slug, users: Math.floor(users) });
  }
  return rows;
}

// ------------------------------------------------------------------ read

interface State {
  url: string;
  rows: PopularityRow[];
  nextCheck: number;
  inflight: Promise<void> | null;
}

let state: State | null = null;

/** Test hook. */
export function resetPopularityState(): void {
  state = null;
}

/**
 * The snapshot's rows, refreshed at most hourly (it changes once a day).
 * Never throws: a missing or broken file means no popularity prior.
 */
export async function getPopularity(publicBaseUrl: string, now = Date.now()): Promise<PopularityRow[]> {
  const url = `${publicBaseUrl.replace(/\/+$/, '')}/${POPULARITY_KEY}`;
  if (!state || state.url !== url) state = { url, rows: [], nextCheck: 0, inflight: null };
  const s = state;
  if (now >= s.nextCheck) {
    s.inflight ??= (async () => {
      try {
        const response = await fetch(url, {
          headers: { Accept: 'application/json' },
          signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
        });
        if (!response.ok) throw new Error(`GET ${POPULARITY_KEY} -> ${response.status}`);
        const body: any = await response.json();
        s.rows = cleanRows(body?.items);
        s.nextCheck = Date.now() + REFRESH_MS;
      } catch (error) {
        logError('popularity_load_failed', error, { hasRows: s.rows.length > 0 });
        s.nextCheck = Date.now() + RETRY_MS;
      }
    })().finally(() => {
      s.inflight = null;
    });
    await s.inflight;
  }
  return s.rows;
}

/** Item id -> users, for the scorer. */
export function popularityByItem(rows: PopularityRow[], has: (id: string) => boolean): Record<string, number> {
  const out: Record<string, number> = {};
  for (const r of rows) {
    const id = itemIdFor(r.kind, r.slug, has);
    if (id) out[id] = (out[id] ?? 0) + r.users;
  }
  return out;
}

// ----------------------------------------------------------------- write

/** New-style secret keys aren't JWTs and go in `apikey` only. */
function serviceHeaders(key: string): Record<string, string> {
  return key.startsWith('sb_secret_') ? { apikey: key } : { apikey: key, Authorization: `Bearer ${key}` };
}

/** The cron job: aggregate counts from Supabase into the bucket. */
export async function writePopularity(env: Env, now = Date.now()): Promise<{ rows: number; key: string } | null> {
  const key = `${env.KEY_PREFIX ?? ''}${POPULARITY_KEY}`;
  if (!env.SUPABASE_SERVICE_ROLE_KEY || !env.CONTENT_BUCKET) {
    logInfo('popularity_skipped', {
      reason: env.SUPABASE_SERVICE_ROLE_KEY ? 'no CONTENT_BUCKET binding' : 'no SUPABASE_SERVICE_ROLE_KEY',
    });
    return null;
  }

  const response = await fetch(`${env.SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/rpc/content_popularity`, {
    method: 'POST',
    headers: {
      ...serviceHeaders(env.SUPABASE_SERVICE_ROLE_KEY),
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({ days: POPULARITY_DAYS }),
    signal: AbortSignal.timeout(RPC_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`content_popularity -> ${response.status}`);
  const rows = cleanRows(await response.json()).sort(
    (a, b) => b.users - a.users || (a.kind + a.slug < b.kind + b.slug ? -1 : 1),
  );

  const body = {
    format: 1,
    generatedAt: new Date(now).toISOString(),
    days: POPULARITY_DAYS,
    items: rows,
  };
  await env.CONTENT_BUCKET.put(key, JSON.stringify(body), {
    httpMetadata: { contentType: 'application/json', cacheControl: 'public, max-age=3600' },
  });
  logInfo('popularity_written', { key, rows: rows.length });
  return { rows: rows.length, key };
}
