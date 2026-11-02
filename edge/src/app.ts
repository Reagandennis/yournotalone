import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { AppEnv } from './env';
import { requireAuth } from './auth';
import { getCatalog } from './catalog';
import { registerSign } from './sign';
import { HttpError, jsonError } from './http';
import { logError } from './log';

export function createApp() {
  const app = new Hono<AppEnv>();

  // No browser client is planned; this just keeps preflights answerable.
  app.use(
    '*',
    cors({
      origin: '*',
      allowMethods: ['GET', 'POST', 'OPTIONS'],
      allowHeaders: ['Authorization', 'Content-Type'],
      maxAge: 86400,
    }),
  );

  // Public.
  app.get('/healthz', async (c) => {
    const catalog = await getCatalog(c.env.PUBLIC_BASE_URL);
    return c.json({ ok: true, catalogVersion: catalog?.version ?? null });
  });

  // Everything under /v1 needs a Supabase access token.
  app.use('/v1/*', requireAuth);
  registerSign(app);
  // Next: registerRecommendations(app);  (POST /v1/recommendations, design §5)

  app.notFound((c) => jsonError(c, 404, 'not_found'));
  app.onError((error, c) => {
    if (error instanceof HttpError) return jsonError(c, error.status, error.code, error.message);
    logError('unhandled', error, { path: c.req.path, method: c.req.method });
    return jsonError(c, 500, 'internal');
  });

  return app;
}
