import * as Sentry from '@sentry/cloudflare';
import type { Env } from './env';
import { createApp } from './app';
import { logInfo } from './log';

const app = createApp();

const handler = {
  fetch(request, env, ctx) {
    return app.fetch(request, env, ctx);
  },

  // Daily 03:00 UTC (wrangler.toml). Popularity snapshot is build step 8.
  async scheduled(controller, _env, _ctx) {
    logInfo('cron', { cron: controller.cron, popularity: 'not yet' });
  },
} satisfies ExportedHandler<Env>;

const withSentry: ExportedHandler<Env> = Sentry.withSentry<Env, unknown, unknown, ExportedHandler<Env>>(
  (env) => ({
    dsn: env.SENTRY_DSN,
    sendDefaultPii: false,
    tracesSampleRate: 0.1,
  }),
  handler,
);

// Sentry wraps the Worker only when SENTRY_DSN is set.
export default {
  fetch(request, env, ctx) {
    return env.SENTRY_DSN ? withSentry.fetch!(request, env, ctx) : handler.fetch(request, env, ctx);
  },
  scheduled(controller, env, ctx) {
    return env.SENTRY_DSN
      ? withSentry.scheduled!(controller, env, ctx)
      : handler.scheduled(controller, env, ctx);
  },
} satisfies ExportedHandler<Env>;
