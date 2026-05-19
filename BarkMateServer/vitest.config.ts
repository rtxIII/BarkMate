import { cloudflareTest } from '@cloudflare/vitest-pool-workers';
import { defineConfig } from 'vitest/config';
import { TEST_APNS_PRIVATE_KEY } from './test/fixtures';

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: './wrangler.jsonc' },
      miniflare: {
        bindings: {
          APNS_PRIVATE_KEY: TEST_APNS_PRIVATE_KEY,
          APNS_TEAM_ID: 'TESTTEAM01',
          APNS_KEY_ID: 'TESTKEYID0',
        },
      },
    }),
  ],
});
