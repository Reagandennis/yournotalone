// POST /v1/media/sign (design §5).
import { AwsClient } from 'aws4fetch';
import type { Hono } from 'hono';
import type { AppEnv, Env } from './env';
import { getCatalog, MEDIA_SLOTS, type CatalogItem, type MediaRef, type MediaSlot } from './catalog';
import { isPremium } from './premium';
import { jsonError } from './http';

export const MAX_ITEMS = 50;
const MAX_ID_LENGTH = 200;
export const EXPIRY_SECONDS = { stream: 6 * 60 * 60, download: 60 * 60 } as const;
type Purpose = keyof typeof EXPIRY_SECONDS;

export interface SignedRef {
  url: string;
  expires: string | null;
  sha256: string;
  bytes: number;
}

interface SignRequest {
  items: string[];
  purpose: Purpose;
}

function parseBody(raw: unknown): SignRequest | string {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return 'body must be a JSON object';
  const { items, purpose } = raw as Record<string, unknown>;
  if (purpose !== 'stream' && purpose !== 'download') return 'purpose must be "stream" or "download"';
  if (!Array.isArray(items) || items.length === 0) return 'items must be a non-empty array';
  if (items.length > MAX_ITEMS) return `at most ${MAX_ITEMS} items`;
  for (const id of items) {
    if (typeof id !== 'string' || id.length === 0 || id.length > MAX_ID_LENGTH) {
      return `each item must be a string of 1–${MAX_ID_LENGTH} characters`;
    }
  }
  return { items: [...new Set(items as string[])], purpose };
}

function needsPremium(item: CatalogItem): boolean {
  return item.premium || MEDIA_SLOTS.some((s) => item.media[s]?.access === 'premium');
}

async function presign(env: Env, ref: MediaRef, seconds: number, now: number): Promise<SignedRef> {
  const client = new AwsClient({
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    service: 's3',
    region: 'auto',
  });
  const url = new URL(
    `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.PRIVATE_BUCKET}/${ref.key}`,
  );
  url.searchParams.set('X-Amz-Expires', String(seconds));
  const signed = await client.sign(url.toString(), {
    method: 'GET',
    aws: { signQuery: true, datetime: amzDate(now) },
  });
  return {
    url: signed.url,
    expires: new Date(now + seconds * 1000).toISOString(),
    sha256: ref.sha256,
    bytes: ref.bytes,
  };
}

/** 20261102T031500Z, matching the timestamp used for `expires`. */
function amzDate(now: number): string {
  return new Date(now).toISOString().replace(/[:-]|\.\d{3}/g, '');
}

export function registerSign(app: Hono<AppEnv>): void {
  app.post('/v1/media/sign', async (c) => {
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return jsonError(c, 400, 'bad_request', 'body must be JSON');
    }
    const parsed = parseBody(raw);
    if (typeof parsed === 'string') return jsonError(c, 400, 'bad_request', parsed);

    const catalog = await getCatalog(c.env.PUBLIC_BASE_URL);
    if (!catalog) return jsonError(c, 503, 'catalog_unavailable');

    const found: CatalogItem[] = [];
    const missing: string[] = [];
    for (const id of parsed.items) {
      const item = catalog.items.get(id);
      if (!item || !MEDIA_SLOTS.some((s) => item.media[s])) missing.push(id);
      else found.push(item);
    }

    // Only ask about premium if something requested needs it.
    if (found.some(needsPremium) && !(await isPremium(c.var.user, c.env))) {
      return jsonError(c, 403, 'premium_required');
    }

    const now = Date.now();
    const seconds = EXPIRY_SECONDS[parsed.purpose];
    const base = c.env.PUBLIC_BASE_URL.replace(/\/+$/, '');
    const urls: Record<string, Partial<Record<MediaSlot, SignedRef>>> = {};
    for (const item of found) {
      const out: Partial<Record<MediaSlot, SignedRef>> = {};
      for (const slot of MEDIA_SLOTS) {
        const ref = item.media[slot];
        if (!ref) continue;
        out[slot] =
          ref.access === 'public'
            ? { url: `${base}/${ref.key}`, expires: null, sha256: ref.sha256, bytes: ref.bytes }
            : await presign(c.env, ref, seconds, now);
      }
      urls[item.id] = out;
    }
    return c.json({ urls, missing });
  });
}
