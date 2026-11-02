import * as Sentry from '@sentry/cloudflare';
import type { Env } from './env';
import { createApp } from './app';
import { logError } from './log';
import { writePopularity } from './recommend/popularity';

const app = createApp();

const handler = {
  fetch(request, env, ctx) {
    return app.fetch(request, env, ctx);
  },

  // Daily 03:00 UTC (wrangler.toml): the popularity snapshot.
  async scheduled(controller, env, _ctx) {
    try {
      await writePopularity(env, controller.scheduledTime);
    } catch (error) {
      // Rethrown so the run shows as failed (and reaches Sentry when set).
      logError('popularity_failed', error, { cron: controller.cron });
      throw error;
    }
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
