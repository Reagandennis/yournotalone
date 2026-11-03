// POST /v1/recommendations (design §5).
//
// request (every field optional; device-only signals ride along, nothing is stored)
//   { "surface": "home", "tz": "Africa/Nairobi", "localTime": "2026-11-02T21:14",
//     "catalogVersion": 42, "locale": "en", "lastMood": 0, "lastMoodAt": "…",
//     "opensByKind": {"sound": 12}, "downloaded": ["…"], "offline": false,
//     "course": {"id": "sleep7", "day": 2}, "limit": 6 }
// response
//   { "items": [{"id": "breathing:Panic reset", "reason": "For right now", "reasonKey": "lead"},
//               {"id": "…", "reason": "Because you felt better after Body scan",
//                "reasonKey": "feltBetter", "reasonArgs": {"title": "meditation:Body scan"}}, …],
//     "rules": "v1", "catalogVersion": 42 }
//   `reason` is English, for apps older than reasonKey; see Reason in score.ts.
//
// Supabase history, the premium check and popularity are fetched in
// parallel; any of them failing just leaves that signal out.
import type { Hono } from 'hono';
import type { AppEnv } from '../env';
import { getCatalog } from '../catalog';
import { isPremium } from '../premium';
import { jsonError } from '../http';
import { getPopularity, popularityByItem } from './popularity';
import { recommend, MAX_LIMIT } from './score';
import { fetchSignals } from './signals';

interface RecommendRequest {
  tz: string | null;
  localTime: string | null;
  lastMood: number | null;
  lastMoodAt: string | null;
  opensByKind: Record<string, number>;
  course: { id: string; day: number } | null;
  limit: number | undefined;
}

const LOCAL_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;
const MAX_STRING = 200;

const optional = (x: unknown) => x === undefined || x === null;
const shortString = (x: unknown, max = MAX_STRING): x is string => typeof x === 'string' && x.length > 0 && x.length <= max;

export function parseBody(raw: unknown): RecommendRequest | string {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return 'body must be a JSON object';
  const b = raw as Record<string, unknown>;

  if (!optional(b.surface) && !(shortString(b.surface, 32) && /^[a-z_]+$/.test(b.surface))) {
    return 'surface must be a short lower-case name';
  }
  if (!optional(b.tz) && !shortString(b.tz, 64)) return 'tz must be a time zone name';
  if (!optional(b.localTime) && !(shortString(b.localTime, 40) && LOCAL_TIME.test(b.localTime))) {
    return 'localTime must be YYYY-MM-DDTHH:mm';
  }
  if (!optional(b.catalogVersion) && !Number.isInteger(b.catalogVersion)) return 'catalogVersion must be an integer';
  if (!optional(b.locale) && !shortString(b.locale, 16)) return 'locale must be a short string';
  if (!optional(b.lastMood) && !(Number.isInteger(b.lastMood) && (b.lastMood as number) >= 0 && (b.lastMood as number) <= 4)) {
    return 'lastMood must be 0–4';
  }
  if (!optional(b.lastMoodAt) && !(shortString(b.lastMoodAt, 40) && !Number.isNaN(Date.parse(b.lastMoodAt)))) {
    return 'lastMoodAt must be an ISO time';
  }
  if (!optional(b.offline) && typeof b.offline !== 'boolean') return 'offline must be a boolean';
  if (!optional(b.downloaded) && !(Array.isArray(b.downloaded) && b.downloaded.length <= 500 && b.downloaded.every((x) => shortString(x)))) {
    return 'downloaded must be a list of ids';
  }
  if (!optional(b.limit) && !(Number.isInteger(b.limit) && (b.limit as number) >= 1 && (b.limit as number) <= MAX_LIMIT)) {
    return `limit must be 1–${MAX_LIMIT}`;
  }

  const opensByKind: Record<string, number> = {};
  if (!optional(b.opensByKind)) {
    const o = b.opensByKind;
    if (!o || typeof o !== 'object' || Array.isArray(o) || Object.keys(o).length > 20) {
      return 'opensByKind must be an object of counts';
    }
    for (const [kind, n] of Object.entries(o)) {
      if (!shortString(kind, 32) || typeof n !== 'number' || !Number.isFinite(n) || n < 0) {
        return 'opensByKind must be an object of counts';
      }
      opensByKind[kind] = n;
    }
  }

  let course: RecommendRequest['course'] = null;
  if (!optional(b.course)) {
    const c = b.course as Record<string, unknown>;
    if (!c || typeof c !== 'object' || !shortString(c.id, 64) || !Number.isInteger(c.day) || (c.day as number) < 0) {
      return 'course must be {id, day}';
    }
    course = { id: c.id, day: c.day as number };
  }

  return {
    tz: (b.tz as string | undefined) ?? null,
    localTime: (b.localTime as string | undefined)?.slice(0, 16) ?? null,
    lastMood: (b.lastMood as number | undefined) ?? null,
    lastMoodAt: (b.lastMoodAt as string | undefined) ?? null,
    opensByKind,
    course,
    limit: (b.limit as number | undefined) ?? undefined,
  };
}

/** `YYYY-MM-DDTHH:mm` in [tz], or UTC if it's missing or unknown. */
export function wallClock(now: number, tz: string | null): string {
  try {
    const parts = Object.fromEntries(
      new Intl.DateTimeFormat('en-GB', {
        timeZone: tz ?? 'UTC',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23',
      })
        .formatToParts(new Date(now))
        .map((p) => [p.type, p.value]),
    );
    return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
  } catch {
    return new Date(now).toISOString().slice(0, 16);
  }
}

export function registerRecommendations(app: Hono<AppEnv>): void {
  app.post('/v1/recommendations', async (c) => {
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return jsonError(c, 400, 'bad_request', 'body must be JSON');
    }
    const req = parseBody(raw);
    if (typeof req === 'string') return jsonError(c, 400, 'bad_request', req);

    const catalog = await getCatalog(c.env.PUBLIC_BASE_URL);
    if (!catalog) return jsonError(c, 503, 'catalog_unavailable');

    const now = Date.now();
    const has = (id: string) => catalog.items.has(id);
    const [history, popularity, premium] = await Promise.all([
      fetchSignals(c.env, c.var.user, has, now),
      getPopularity(c.env.PUBLIC_BASE_URL, now),
      isPremium(c.var.user, c.env),
    ]);

    const result = recommend(catalog.scoring, {
      now: new Date(now).toISOString(),
      localTime: req.localTime ?? wallClock(now, req.tz),
      premium,
      goals: c.var.user.goals,
      lastMood: req.lastMood,
      lastMoodAt: req.lastMoodAt,
      opensByKind: req.opensByKind,
      course: req.course,
      ...history,
      popularity: popularityByItem(popularity, has),
      limit: req.limit,
    });
    // Per-person: never cached anywhere on the way back.
    c.header('Cache-Control', 'private, no-store');
    return c.json({ ...result, catalogVersion: catalog.version });
  });
}
