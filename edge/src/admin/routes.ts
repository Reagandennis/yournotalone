// The admin page and its API (docs/backend-design.md §8a).
//
//   GET  /admin                          the page (public; it holds no secrets)
//   GET  /admin/api/items                every item file, the vocabulary and icons, raw
//   POST /admin/api/items                save one item (and its recording) to main
//   POST /admin/api/uploads              start uploading a recording
//   PUT  /admin/api/uploads/:id/:part    one part (up to 50 MB)
//   POST /admin/api/uploads/:id/complete finish it
//   DELETE /admin/api/uploads/:id        give up on it
//   POST /admin/api/publish              publish main to staging or production
//   GET  /admin/api/status               recent publishes, and what's live
//
// Everything under /admin/api needs a Supabase session whose app_metadata
// has content_admin: true, which only the service role can set
// (supabase/account_ops.sql). Recordings go straight into R2 under
// private/masters/ (blocked on the public domain); item files go to
// GitHub, and the content workflow checks, transcodes, translates and
// publishes them.

import type { Hono, MiddlewareHandler } from 'hono';
import type { AppEnv } from '../env';
import { requireAuth } from '../auth';
import { HttpError, jsonError } from '../http';
import { commitFiles, readFile, readTree, recentRuns, startPublish } from './github';
import {
  indexItems, ITEMS_DIR, MASTER_NAME, MASTERS_PATH, MASTERS_PREFIX, parseItem, prepare, toYaml, withMaster,
  type Item, type Master,
} from './items';
import { ADMIN_PAGE } from './page';

const MIN_PART = 5 * 1024 * 1024;
const MAX_PART = 50 * 1024 * 1024;
const MAX_RECORDING = 2 * 1024 * 1024 * 1024;

const requireAdmin: MiddlewareHandler<AppEnv> = async (c, next) => {
  if (!c.var.user.contentAdmin) return jsonError(c, 403, 'not_admin');
  if (!c.env.ADMIN_GITHUB_TOKEN || !c.env.GITHUB_REPO) return jsonError(c, 503, 'admin_not_configured');
  await next();
};

function bucket(c: { env: AppEnv['Bindings'] }): R2Bucket {
  if (!c.env.CONTENT_BUCKET) throw new HttpError(503, 'admin_not_configured', 'no CONTENT_BUCKET binding');
  return c.env.CONTENT_BUCKET;
}

async function body<T>(c: { req: { json: () => Promise<unknown> } }): Promise<T> {
  try {
    return (await c.req.json()) as T;
  } catch {
    throw new HttpError(400, 'bad_request', 'body must be JSON');
  }
}

/** Where the catalogue pointer for [target] is, from this Worker's own base. */
function latestUrl(publicBase: string, target: 'staging' | 'production'): string {
  const root = publicBase.replace(/\/+$/, '').replace(/\/staging$/, '');
  return `${root}${target === 'staging' ? '/staging' : ''}/catalog/latest.json`;
}

async function live(url: string): Promise<unknown> {
  try {
    const res = await fetch(url, { cf: { cacheTtl: 0 } } as RequestInit);
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
}

export function registerAdmin(app: Hono<AppEnv>): void {
  app.get('/admin', (c) => {
    const nonce = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(16))));
    const supabase = c.env.SUPABASE_URL.replace(/\/+$/, '');
    c.header('Cache-Control', 'no-store');
    c.header('X-Frame-Options', 'DENY');
    c.header('Referrer-Policy', 'no-referrer');
    c.header('X-Content-Type-Options', 'nosniff');
    c.header(
      'Content-Security-Policy',
      [
        "default-src 'none'",
        `script-src 'nonce-${nonce}' https://esm.sh`,
        "style-src 'self' 'unsafe-inline'",
        `connect-src 'self' ${supabase} https://esm.sh`,
        "img-src 'self' data:",
        "base-uri 'none'",
        "form-action 'self'",
        "frame-ancestors 'none'",
      ].join('; '),
    );
    return c.html(
      ADMIN_PAGE.replaceAll('__NONCE__', nonce)
        .replace('__SUPABASE_URL__', supabase)
        .replace('__SUPABASE_KEY__', c.env.SUPABASE_ANON_KEY),
    );
  });

  app.use('/admin/api/*', requireAuth, requireAdmin);

  app.get('/admin/api/items', async (c) => {
    const [files, vocab, icons, masters] = await Promise.all([
      readTree(c.env, ITEMS_DIR),
      readFile(c.env, 'content/vocab.yaml'),
      readFile(c.env, 'lib/content/content_icons.dart'),
      readFile(c.env, MASTERS_PATH),
    ]);
    c.header('Cache-Control', 'no-store');
    return c.json({ files, vocab, icons, masters });
  });

  app.post('/admin/api/items', async (c) => {
    const req = await body<{ path?: string | null; item: Item; master?: Master & { role?: string } }>(c);
    const files = await readTree(c.env, ITEMS_DIR);
    const index = indexItems(files);
    let before: { item: Item; path: string } | null = null;
    if (req.path) {
      const file = files.find((f) => f.path === req.path);
      if (!file) return jsonError(c, 404, 'not_found', `${req.path} isn't on main`);
      before = { item: parseItem(file.text), path: file.path };
    }
    const { item, path } = prepare(req.item, index, before, new Date().toISOString().slice(0, 10));

    const changes = [{ path, text: toYaml(item) }];
    if (req.master) {
      const m = req.master;
      if (!MASTER_NAME.test(m.name)) return jsonError(c, 400, 'invalid_item', 'bad recording name');
      const role = m.role === 'narration' ? 'narration' : 'audio';
      if (item.body?.[role] !== `Sounds/${m.name}`) {
        return jsonError(c, 400, 'invalid_item', `body.${role} must be Sounds/${m.name}`);
      }
      const key = MASTERS_PREFIX + m.name;
      const stored = await bucket(c).head(key);
      if (!stored || stored.size !== m.bytes) return jsonError(c, 400, 'invalid_item', "the recording isn't uploaded");
      if (!/^[0-9a-f]{64}$/.test(m.sha256)) return jsonError(c, 400, 'invalid_item', 'bad sha256');
      const masters = await readFile(c.env, MASTERS_PATH);
      changes.push({ path: MASTERS_PATH, text: withMaster(masters, { name: m.name, key, bytes: m.bytes, sha256: m.sha256 }) });
    }

    const title = item.text?.en?.title ?? item.id;
    const verb = before ? (item.status === 'retired' && before.item.status !== 'retired' ? 'Retire' : 'Update') : 'Add';
    const sha = await commitFiles(c.env, changes, `${verb} ${item.kind}: ${title}\n\nSaved from the admin page.`);
    return c.json({ id: item.id, path, commit: sha });
  });

  // ---------------------------------------------------------- recordings

  app.post('/admin/api/uploads', async (c) => {
    const req = await body<{ name: string; bytes: number; contentType?: string }>(c);
    if (typeof req.name !== 'string' || !MASTER_NAME.test(req.name)) {
      return jsonError(c, 400, 'bad_request', 'name must be lower-case words with dashes and an audio extension');
    }
    if (!Number.isInteger(req.bytes) || req.bytes <= 0 || req.bytes > MAX_RECORDING) {
      return jsonError(c, 400, 'bad_request', 'bytes must be a positive size under 2 GB');
    }
    const key = MASTERS_PREFIX + req.name;
    const existing = await bucket(c).head(key);
    // Same name, same size: already there (an upload that got as far as
    // completing before the save failed). A different file needs a new name.
    if (existing) {
      if (existing.size === req.bytes) return c.json({ key, done: true });
      return jsonError(c, 409, 'name_taken', `${req.name} is already a different recording`);
    }
    const upload = await bucket(c).createMultipartUpload(key, {
      httpMetadata: { contentType: req.contentType || 'application/octet-stream', cacheControl: 'private, no-store' },
    });
    return c.json({ key, uploadId: upload.uploadId, partSize: 25 * 1024 * 1024 });
  });

  app.put('/admin/api/uploads/:id/:part', async (c) => {
    const key = c.req.query('key') ?? '';
    const part = Number(c.req.param('part'));
    if (!key.startsWith(MASTERS_PREFIX) || !MASTER_NAME.test(key.slice(MASTERS_PREFIX.length))) {
      return jsonError(c, 400, 'bad_request', 'bad key');
    }
    if (!Number.isInteger(part) || part < 1 || part > 10_000) return jsonError(c, 400, 'bad_request', 'bad part');
    const size = Number(c.req.header('Content-Length'));
    if (!(size > 0 && size <= MAX_PART)) return jsonError(c, 413, 'part_too_large', 'parts are up to 50 MB');
    const body = c.req.raw.body;
    if (!body) return jsonError(c, 400, 'bad_request', 'empty part');
    const upload = bucket(c).resumeMultipartUpload(key, c.req.param('id'));
    const uploaded = await upload.uploadPart(part, body);
    return c.json({ partNumber: uploaded.partNumber, etag: uploaded.etag, minPart: MIN_PART });
  });

  app.post('/admin/api/uploads/:id/complete', async (c) => {
    const req = await body<{ key: string; parts: R2UploadedPart[] }>(c);
    if (typeof req.key !== 'string' || !req.key.startsWith(MASTERS_PREFIX) || !Array.isArray(req.parts)) {
      return jsonError(c, 400, 'bad_request');
    }
    const object = await bucket(c).resumeMultipartUpload(req.key, c.req.param('id')).complete(req.parts);
    return c.json({ key: object.key, bytes: object.size });
  });

  app.delete('/admin/api/uploads/:id', async (c) => {
    const key = c.req.query('key') ?? '';
    if (!key.startsWith(MASTERS_PREFIX)) return jsonError(c, 400, 'bad_request');
    await bucket(c).resumeMultipartUpload(key, c.req.param('id')).abort();
    return c.json({ ok: true });
  });

  // ---------------------------------------------------------- publishing

  app.post('/admin/api/publish', async (c) => {
    const req = await body<{ target?: string }>(c);
    if (req.target !== 'staging' && req.target !== 'production') {
      return jsonError(c, 400, 'bad_request', 'target must be staging or production');
    }
    await startPublish(c.env, req.target);
    return c.json({ ok: true });
  });

  app.get('/admin/api/status', async (c) => {
    const [runs, staging, production] = await Promise.all([
      recentRuns(c.env),
      live(latestUrl(c.env.PUBLIC_BASE_URL, 'staging')),
      live(latestUrl(c.env.PUBLIC_BASE_URL, 'production')),
    ]);
    c.header('Cache-Control', 'no-store');
    return c.json({ runs, live: { staging, production } });
  });
}
