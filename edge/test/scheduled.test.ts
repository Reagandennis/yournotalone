import { createExecutionContext, createScheduledController, waitOnExecutionContext } from 'cloudflare:test';
import { expect, it, vi } from 'vitest';
import worker from '../src/index';
import { testEnv } from './helpers';

it('cron stub logs and does nothing else', async () => {
  const log = vi.spyOn(console, 'log').mockImplementation(() => {});
  const fetchSpy = vi.spyOn(globalThis, 'fetch');
  const ctx = createExecutionContext();
  await worker.scheduled(createScheduledController({ cron: '0 3 * * *', scheduledTime: Date.now() }), testEnv, ctx);
  await waitOnExecutionContext(ctx);
  expect(fetchSpy).not.toHaveBeenCalled();
  expect(JSON.parse(log.mock.calls[0][0])).toMatchObject({ event: 'cron', popularity: 'not yet' });
  vi.restoreAllMocks();
});
