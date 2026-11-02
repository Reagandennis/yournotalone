import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

// Tests run inside workerd. Vars from wrangler.toml are overridden with
// test values; every outbound fetch is mocked in test/helpers.ts.
export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: './wrangler.toml' },
      miniflare: {
        bindings: {
          SUPABASE_URL: 'https://test-project.supabase.co',
          PUBLIC_BASE_URL: 'https://cdn.test',
          R2_ACCOUNT_ID: 'f7e65097ea4facdba994ee51d751705a',
          BUCKET: 'yournotalone',
          KEY_PREFIX: 'staging/',
          PRO_ENTITLEMENT_ID: 'entl_pro_test',
          PRO_ENTITLEMENT_LOOKUP_KEY: 'Techgetafrica Pro',
          R2_ACCESS_KEY_ID: 'test-access-key',
          R2_SECRET_ACCESS_KEY: 'test-secret-key',
          REVENUECAT_SECRET_KEY: 'sk_test',
          REVENUECAT_PROJECT_ID: 'proj_test',
          SENTRY_DSN: '',
        },
      },
    }),
  ],
});
