// The person's own history from Supabase (design §5), read through
// PostgREST with their access token, so row-level security limits every
// query to their rows. Three small reads in parallel, each with its own
// timeout. A read that fails (Supabase down, a table not migrated yet)
// counts as "no history" for that signal; it never fails the request.

import type { AuthUser, Env } from '../env';
import { logError } from '../log';
import type { Signals } from './score';

const TIMEOUT_MS = 1_500;
const WINDOW_DAYS = 90;
const MAX_ROWS = 500;

export type UserSignals = Required<Pick<Signals, 'sessions' | 'feelings' | 'saved'>>;

/**
 * The item id a `practice_sessions` / `session_feelings` row points at.
 * Rows store the kind and the title (`slug`); urge surfing is logged as a
 * meditation but listed under recovery, and newer items use a slug id.
 */
export function itemIdFor(kind: string, slug: string, has: (id: string) => boolean): string | null {
  const candidates = [`${kind}:${slug}`, ...(kind === 'meditation' ? [`recovery:${slug}`] : []), slug];
  return candidates.find(has) ?? null;
}

async function select(env: Env, user: AuthUser, table: string, query: Record<string, string>): Promise<any[]> {
  const url = new URL(`${env.SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/${table}`);
  // RLS already limits rows to the user; the filter lets Postgres use the index.
  url.searchParams.set('user_id', `eq.${user.id}`);
  for (const [k, v] of Object.entries(query)) url.searchParams.set(k, v);
  url.searchParams.set('limit', String(MAX_ROWS));
  const response = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${user.token}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`${table} -> ${response.status}`);
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error(`${table} returned no array`);
  return rows;
}

async function orEmpty<T>(table: string, read: () => Promise<T[]>): Promise<T[]> {
  try {
    return await read();
  } catch (error) {
    logError('supabase_signal_failed', error, { table });
    return [];
  }
}

const str = (x: unknown): x is string => typeof x === 'string' && x.length > 0;

export async function fetchSignals(
  env: Env,
  user: AuthUser,
  has: (id: string) => boolean,
  now: number,
): Promise<UserSignals> {
  const since = new Date(now - WINDOW_DAYS * 86_400_000).toISOString();
  const [sessions, feelings, saved] = await Promise.all([
    orEmpty('practice_sessions', async () => {
      const rows = await select(env, user, 'practice_sessions', {
        select: 'kind,slug,completed_at',
        completed_at: `gte.${since}`,
        order: 'completed_at.desc',
      });
      return rows.flatMap((r) => {
        const id = str(r?.kind) && str(r?.slug) ? itemIdFor(r.kind, r.slug, has) : null;
        return id && str(r.completed_at) ? [{ id, at: r.completed_at }] : [];
      });
    }),
    orEmpty('session_feelings', async () => {
      const rows = await select(env, user, 'session_feelings', {
        select: 'kind,slug,feeling,created_at',
        created_at: `gte.${since}`,
        order: 'created_at.desc',
      });
      return rows.flatMap((r) => {
        const id = str(r?.kind) && str(r?.slug) ? itemIdFor(r.kind, r.slug, has) : null;
        const feeling = r?.feeling;
        return id && str(r.created_at) && (feeling === -1 || feeling === 0 || feeling === 1)
          ? [{ id, feeling, at: r.created_at }]
          : [];
      });
    }),
    orEmpty('saved_items', async () => {
      const rows = await select(env, user, 'saved_items', { select: 'item_id', order: 'saved_at.desc' });
      return rows.map((r) => r?.item_id).filter((id): id is string => str(id) && has(id));
    }),
  ]);
  return { sessions, feelings, saved };
}
